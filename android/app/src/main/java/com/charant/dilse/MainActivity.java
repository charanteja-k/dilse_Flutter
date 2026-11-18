package com.charant.dilse;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.os.Build;
import android.os.Bundle;
import com.ryanheise.audioservice.AudioServiceActivity;

public class MainActivity extends AudioServiceActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        createNotificationChannel();
        keepAudioServiceDrawables();
    }

    private void keepAudioServiceDrawables() {
        int[] drawables = new int[] {
            R.drawable.audio_service_play_arrow,
            R.drawable.audio_service_pause,
            R.drawable.audio_service_stop,
            R.drawable.audio_service_skip_next,
            R.drawable.audio_service_skip_previous,
            R.drawable.audio_service_fast_forward,
            R.drawable.audio_service_fast_rewind,
            R.drawable.ic_stat_music,
        };
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            String channelId = "com.charant.dilse.playback";
            CharSequence channelName = "DilSe Playback";
            String channelDescription = "Music playback controls and lock screen notification";
            int importance = NotificationManager.IMPORTANCE_LOW;

            NotificationChannel channel = new NotificationChannel(channelId, channelName, importance);
            channel.setDescription(channelDescription);
            channel.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);
            channel.setShowBadge(true);

            NotificationManager notificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
            if (notificationManager != null) {
                notificationManager.createNotificationChannel(channel);
            }
        }
    }
}
