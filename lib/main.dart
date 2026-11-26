import 'package:audio_service/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'data/datasources/local/audio_handler.dart';
import 'data/datasources/local/audio_stream_buffer_manager.dart';
import 'data/datasources/local/queue_manager.dart';
import 'data/datasources/local/soloud_audio_driver.dart';
import 'data/datasources/remote/cloudflare_edge_datasource.dart';
import 'data/datasources/remote/github_update_datasource.dart';
import 'data/repositories/audio_repository.dart';
import 'data/repositories/audio_repository_impl.dart';
import 'data/repositories/update_repository.dart';
import 'data/repositories/update_repository_impl.dart';
import 'data/datasources/local/storage_datasource.dart';
import 'core/theme/theme_viewmodel.dart';
import 'features/app_update/viewmodels/update_viewmodel.dart';
import 'features/audio_player/viewmodels/audio_player_viewmodel.dart';
import 'features/downloads/viewmodels/downloads_viewmodel.dart';
import 'features/home/viewmodels/home_viewmodel.dart';
import 'features/home/views/home_screen.dart';
import 'features/library/viewmodels/library_viewmodel.dart';
import 'features/search/viewmodels/search_viewmodel.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cap image memory cache to avoid OOM crashes on budget devices (AGENTS.md §3.4)
  PaintingBinding.instance.imageCache.maximumSize = 100;

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize AudioService for lockscreen media controls and background notification
  DilSeAudioHandler? audioHandler;
  try {
    audioHandler = await AudioService.init(
      builder: () => DilSeAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.charant.dilse.playback',
        androidNotificationChannelName: 'DilSe Playback',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: false,
        androidShowNotificationBadge: true,
        androidNotificationIcon: 'drawable/ic_stat_music',
        notificationColor: Color(0xFF121214),
      ),
    );
  } catch (e) {
    debugPrint('[AudioService] Init note: $e');
  }

  runApp(DilseApp(audioHandler: audioHandler));
}

class DilseApp extends StatelessWidget {
  final DilSeAudioHandler? audioHandler;

  const DilseApp({super.key, this.audioHandler});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        if (audioHandler != null)
          Provider<DilSeAudioHandler>.value(value: audioHandler!),

        // HTTP Client
        Provider<http.Client>(
          create: (_) => http.Client(),
          dispose: (_, client) => client.close(),
        ),

        // Remote Datasource
        ProxyProvider<http.Client, CloudflareEdgeDatasource>(
          update: (context, client, previous) =>
              previous ?? CloudflareEdgeDatasourceImpl(client: client),
        ),

        // Audio Repository
        ProxyProvider<CloudflareEdgeDatasource, AudioRepository>(
          update: (context, datasource, previous) =>
              previous ?? AudioRepositoryImpl(remoteDatasource: datasource),
        ),

        // Audio Stream Buffer Manager
        ProxyProvider<http.Client, AudioStreamBufferManager>(
          update: (context, client, previous) =>
              previous ?? AudioStreamBufferManagerImpl(client: client),
        ),

        // Audio Driver (just_audio powered ExoPlayer driver with AudioService handler)
        ProxyProvider<AudioStreamBufferManager, SoLoudAudioDriver>(
          update: (context, bufferManager, previous) =>
              previous ?? JustAudioDriverImpl(audioHandler: audioHandler),
          dispose: (context, driver) => driver.dispose(),
        ),

        // Storage Datasource (Library, Downloads, and Player Liked State)
        Provider<StorageDatasource>(
          create: (_) => StorageDatasourceImpl(),
        ),

        // Queue Manager
        Provider<QueueManager>(
          create: (_) => QueueManager(),
        ),

        // ViewModels
        ChangeNotifierProxyProvider4<SoLoudAudioDriver, QueueManager, AudioRepository, StorageDatasource, AudioPlayerViewModel>(
          create: (context) => AudioPlayerViewModel(
            audioDriver: context.read<SoLoudAudioDriver>(),
            queueManager: context.read<QueueManager>(),
            audioRepository: context.read<AudioRepository>(),
            storageDatasource: context.read<StorageDatasource>(),
            audioHandler: audioHandler,
          ),
          update: (_, driver, queue, repo, storage, previous) =>
              previous ??
              AudioPlayerViewModel(
                audioDriver: driver,
                queueManager: queue,
                audioRepository: repo,
                storageDatasource: storage,
                audioHandler: audioHandler,
              ),
        ),

        ChangeNotifierProxyProvider<AudioRepository, HomeViewModel>(
          create: (context) => HomeViewModel(
            audioRepository: context.read<AudioRepository>(),
          ),
          update: (_, repo, previous) =>
              previous ?? HomeViewModel(audioRepository: repo),
        ),

        ChangeNotifierProxyProvider<AudioRepository, SearchViewModel>(
          create: (context) => SearchViewModel(
            audioRepository: context.read<AudioRepository>(),
          ),
          update: (_, repo, previous) =>
              previous ?? SearchViewModel(audioRepository: repo),
        ),

        // Library & Downloads ViewModels
        ChangeNotifierProxyProvider<StorageDatasource, LibraryViewModel>(
          create: (context) => LibraryViewModel(
            storageDatasource: context.read<StorageDatasource>(),
          ),
          update: (_, storage, previous) =>
              previous ?? LibraryViewModel(storageDatasource: storage),
        ),

        ChangeNotifierProxyProvider<StorageDatasource, DownloadsViewModel>(
          create: (context) => DownloadsViewModel(
            storageDatasource: context.read<StorageDatasource>(),
          ),
          update: (_, storage, previous) =>
              previous ?? DownloadsViewModel(storageDatasource: storage),
        ),

        // GitHub App Updates Layer
        ProxyProvider<http.Client, GithubUpdateDatasource>(
          update: (context, client, previous) =>
              previous ?? GithubUpdateDatasourceImpl(client: client),
        ),

        ProxyProvider<GithubUpdateDatasource, UpdateRepository>(
          update: (context, datasource, previous) =>
              previous ?? UpdateRepositoryImpl(remoteDatasource: datasource),
        ),

        ChangeNotifierProxyProvider<UpdateRepository, UpdateViewModel>(
          create: (context) => UpdateViewModel(
            updateRepository: context.read<UpdateRepository>(),
          ),
          update: (_, repo, previous) =>
              previous ?? UpdateViewModel(updateRepository: repo),
        ),

        // Application Theme ViewModel (OLED Dark <-> Clean Light mode)
        ChangeNotifierProvider<ThemeViewModel>(
          create: (_) => ThemeViewModel()..loadThemePreference(),
        ),
      ],
      child: Consumer<ThemeViewModel>(
        builder: (context, themeVm, _) {
          return MaterialApp(
            title: 'DilSe',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeVm.themeMode,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
