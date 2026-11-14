import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'data/datasources/local/audio_stream_buffer_manager.dart';
import 'data/datasources/local/queue_manager.dart';
import 'data/datasources/local/soloud_audio_driver.dart';
import 'data/datasources/remote/cloudflare_edge_datasource.dart';
import 'data/datasources/remote/github_update_datasource.dart';
import 'data/repositories/audio_repository.dart';
import 'data/repositories/audio_repository_impl.dart';
import 'data/repositories/update_repository.dart';
import 'data/repositories/update_repository_impl.dart';
import 'features/app_update/viewmodels/update_viewmodel.dart';
import 'features/audio_player/viewmodels/audio_player_viewmodel.dart';
import 'features/home/viewmodels/home_viewmodel.dart';
import 'features/home/views/home_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const DilseApp());
}

class DilseApp extends StatelessWidget {
  const DilseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
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

        // Audio Driver (just_audio powered ExoPlayer driver)
        ProxyProvider<AudioStreamBufferManager, SoLoudAudioDriver>(
          update: (context, bufferManager, previous) =>
              previous ?? JustAudioDriverImpl(),
          dispose: (context, driver) => driver.dispose(),
        ),

        // Queue Manager
        Provider<QueueManager>(
          create: (_) => QueueManager(),
        ),

        // ViewModels
        ChangeNotifierProxyProvider3<SoLoudAudioDriver, QueueManager, AudioRepository, AudioPlayerViewModel>(
          create: (context) => AudioPlayerViewModel(
            audioDriver: context.read<SoLoudAudioDriver>(),
            queueManager: context.read<QueueManager>(),
            audioRepository: context.read<AudioRepository>(),
          ),
          update: (_, driver, queue, repo, previous) =>
              previous ??
              AudioPlayerViewModel(
                audioDriver: driver,
                queueManager: queue,
                audioRepository: repo,
              ),
        ),

        ChangeNotifierProxyProvider<AudioRepository, HomeViewModel>(
          create: (context) => HomeViewModel(
            audioRepository: context.read<AudioRepository>(),
          ),
          update: (_, repo, previous) =>
              previous ?? HomeViewModel(audioRepository: repo),
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
      ],
      child: MaterialApp(
        title: 'DilSe',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const HomeScreen(),
      ),
    );
  }
}
