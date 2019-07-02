import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:floop/floop.dart';

// Create your own store from ObservedMap instead of using `floop` (it's the same)
Map<String, dynamic> store = ObservedMap();
List<Oscillator> oscillators = [];

List oscillatorTimes = [1, 2, 3, 5, 10, 20, 100, 1000];

void main() {
  initializeStoreValues();
  initializeOsicillators();
  runApp(
    MaterialApp(
      title: 'Task Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: IconThumbnails()
    )
  );
}

initializeStoreValues() {
  store['showBig'] = false;
  store['animate'] = false;
  store['timeStamper'] = TimeStamper();
  store['iconWidgets'] = icons.map((ic) => AnimatedIconButton(ic)).toList();  // save final widgets
}

initializeOsicillators() {
  oscillators = [
    Oscillator(
      (Oscillator osc) => store['angle'] = osc.proportionDouble(2*pi),
      5000
    ),
    Oscillator(
      (Oscillator osc) => store['colorOffset'] = osc.proportionInt(256),
      5000
    ),
    Oscillator(
      (Oscillator osc) {
        List widgets = store['iconWidgets'];
        store['iconWidgets'] = shiftRight(widgets, osc.proportionInt(widgets.length));
      },
      2000*1000, 200
    )
  ];
}

shiftRight(List list, int shift) {
  return list.sublist(list.length-shift) + list.sublist(0, list.length-shift);
}

class AnimatedIconButton extends StatelessWidget with Floop {
  final IconData iconData;
  final double size;

  AnimatedIconButton(this.iconData, {this.size = 40.0, oscillatorName=''});

  updateAnimations() {
    var sameIcon = store['selectedIcon'] == iconData;
    var animationRunning = store['animate'];
    var shouldHide = !animationRunning && sameIcon && store['showBig'];
    var shouldStartAnimation = !animationRunning && !shouldHide;
    var shouldAnimate = !sameIcon;
    print('shouldAnimate $shouldAnimate');

    store['showBig'] = !shouldHide;
    if(shouldStartAnimation) runOscillators();
    if(!shouldAnimate) stopOscillators();
    store['animate'] = shouldAnimate;
    
    store['selectedIcon'] = iconData;
  }

  @override
  Widget buildWithFloop(BuildContext context) {
    int c = store['iconGradient'] ?? 0;
    // int c = (t*256)~/5000;
    var color = store['animate'] ? 
      Color.fromRGBO(c+90, c+180, Random().nextInt(256), 1.0) :
      IconTheme.of(context).color;
    return IconButton(
      color: iconData==icons[0] ? Colors.red : color,
      splashColor: Colors.blue,
      iconSize: size,
      icon: Icon(iconData),
      onPressed: updateAnimations,        
    );
  }
}

runOscillators() {
  print('Running ${oscillators.length} Oscillators');
  for(Oscillator osc in oscillators) osc.start();
  // oscillator(1, 50);
  // oscillator(2, 50);
  // oscillator(5, 100);
  // oscillator(20);
  // oscillator(100);
  // oscillator(500);
  // oscillator(1000);
  // oscillator(3000);
}

stopOscillators() {
  print('STOP oscillators');
  oscillators.forEach((Oscillator osc) => osc.stop());
}

rotateWidget(Widget widget, [speed=5]) {
  // var oscillatorName = 'p${speed}s';
  // num t = (store[oscillatorName] ?? 0)/(1000*speed);
  double t = store['angle'] ?? 0;
  return Transform.rotate(
    angle: t*2*pi,
    child: widget
  );
}

/// Creast an oscillator of `period` seconds.
/// Stores oscillator state in the store.
void oscillator(int period, [int minUpdateMillis=1000, int refreshRateMillis=50]) {
  var field = 'p${period.toInt().toString()}s';   // will save value in store[field]
  if(!store.containsKey(field)) store[field] = 0;
  var stopwatch = TimeStamper();
  period *= 1000; // transform to millis
  int time = store[field];
  oscillate() {
    Future.delayed(
      Duration(milliseconds: refreshRateMillis),
      () {
        if(!store['animate']) return;

        // stopwatch.printDelta('Oscilator $field interval');
        time = (time+stopwatch.delta.inMilliseconds)%period;
        int diff = (time-store[field]+period)%period;
        if(diff > minUpdateMillis) store[field] = time;
        oscillate();
      },
    );
  }

  oscillate();  
}

class IconThumbnails extends StatelessWidget with Floop {
  reset() {
    store['animate'] = false;
    for(Oscillator osc in oscillators ?? []) {
      osc.stop();
      osc.reset();
      initializeStoreValues();
    }
    store['p1s'] = 0;
    store['p2s'] = 0;
    store['p5s'] = 0;
    store['p20s'] = 0;
    store['p100s'] = 0;
    store['p500s'] = 0;
    store['p1000s'] = 0;
    store['p3000s'] = 0;
  }

  @override
  Widget buildWithFloop(BuildContext context) {
    // int t1s = store['oscillators'] ?? 0;
    // List iconWidgets = store['iconWidgets'] ?? [];
    // int shift = (t1s*iconWidgets.length)~/1000000;
    // int mid = iconWidgets.length-shift;
    // List widgets = iconWidgets.sublist(mid) + iconWidgets.sublist(0, mid);
    return Scaffold(
      body: Column(
        children: [
          store['showBig'] ? DisplayBox(): Container(),
          Expanded(
            child: GridView.count(
              crossAxisCount: 4,
              padding: EdgeInsets.all(5.0),
              children: store['iconWidgets'].cast<Widget>()
            )
          )
        ]
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.refresh),
        onPressed: reset,
      ),
    );
  }
}

class DisplayBox extends StatelessWidget with Floop {
  @override
  Widget buildWithFloop(BuildContext context) {
    (store['timeStamper'] as TimeStamper)?.printDelta(
      'Building big with angle ${store['angle']} icon after');
    return Container(
      height: 300.0,
      child: Center(
        child: rotateWidget(AnimatedIconButton(store['selectedIcon'], size: 200.0), 2),
      ),
    );
  }
}

class Oscillator extends Stopwatch {
  int periodMilliseconds;
  int refreshRateMilliseconds;
  bool _stop = true;
  Function f;

  Oscillator(this.f, this.periodMilliseconds, [this.refreshRateMilliseconds=50]);

  stop() {
    super.stop();
    _stop = true;
  } 

  reset() {
    stop();
    super.reset();
    f(this);
  }

  start([int refreshRate]) {
    if(!_stop) throw StateError('The oscillators was already running');
    refreshRate = refreshRate ?? refreshRateMilliseconds;
    _stop = false;
    super.start();
    print('Started oscillator $periodMilliseconds');
    run() {
      Future.delayed(
        Duration(milliseconds: refreshRate),
        () {
          // print('Running Oscillator $periodMilliseconds');
          if(_stop) {
            stop();
            return;
          }
          f(this);
          run();
        }
      );
    }
    run();
  }

  int proportionInt(int number) {
    int current = elapsed.inMilliseconds % periodMilliseconds;
    var res = (number*current)~/periodMilliseconds;
    print('Proportion int is $res of $number');
    return res;
  }

  double proportionDouble(double number) {
    double current = number*elapsed.inMilliseconds % periodMilliseconds;
    return current/periodMilliseconds;
  }
}

class TimeStamper extends Stopwatch {
  Duration _previuosRead;
  Duration _delta;
  
  TimeStamper() {
    start();
    _previuosRead = Duration.zero;
  }

  Duration get delta {
    _delta = elapsed-_previuosRead;
    _previuosRead = elapsed;
    return _delta;
  }
  
  Duration printDelta([String message='Time taken:']) {
    var delta = this.delta;
    print(message + ' ' + delta.inMilliseconds.toString() + ' ms');
    _previuosRead = elapsed;
    return delta;
  }
}

const List<IconData> icons = [
  Icons.ac_unit,
  Icons.access_alarm,
  Icons.access_alarms,
  Icons.access_time,
  Icons.accessibility,
  Icons.accessibility_new,
  Icons.accessible,
  Icons.accessible_forward,
  Icons.account_balance,
  Icons.account_balance_wallet,
  Icons.account_box,
  Icons.account_circle,
  Icons.adb,
  Icons.add,
  Icons.add_a_photo,
  Icons.add_alarm,
  Icons.add_alert,
  Icons.add_box,
  Icons.add_call,
  Icons.add_circle,
  Icons.add_circle_outline,
  Icons.add_comment,
  Icons.add_location,
  Icons.add_photo_alternate,
  Icons.add_shopping_cart,
  Icons.add_to_home_screen,
  Icons.add_to_photos,
  Icons.add_to_queue,
  Icons.adjust,
  Icons.airline_seat_flat,
  Icons.airline_seat_flat_angled,
  Icons.airline_seat_individual_suite,
  Icons.airline_seat_legroom_extra,
  Icons.airline_seat_legroom_normal,
  Icons.airline_seat_legroom_reduced,
  Icons.airline_seat_recline_extra,
  Icons.airline_seat_recline_normal,
  Icons.airplanemode_active,
  Icons.airplanemode_inactive,
  Icons.airplay,
  Icons.airport_shuttle,
  Icons.alarm,
  Icons.alarm_add,
  Icons.alarm_off,
  Icons.alarm_on,
  Icons.album,
  Icons.all_inclusive,
  Icons.all_out,
  Icons.alternate_email,
  Icons.android,
  Icons.announcement,
  Icons.apps,
  Icons.archive,
  Icons.arrow_back,
  Icons.arrow_back_ios,
  Icons.arrow_downward,
  Icons.arrow_drop_down,
  Icons.arrow_drop_down_circle,
  Icons.arrow_drop_up,
  Icons.arrow_forward,
  Icons.arrow_forward_ios,
  Icons.arrow_left,
  Icons.arrow_right,
  Icons.arrow_upward,
  Icons.art_track,
  Icons.aspect_ratio,
  Icons.assessment,
  Icons.assignment,
  Icons.assignment_ind,
  Icons.assignment_late,
  Icons.assignment_return,
  Icons.assignment_returned,
  Icons.assignment_turned_in,
  Icons.assistant,
  Icons.assistant_photo,
  Icons.atm,
  Icons.attach_file,
  Icons.attach_money,
  Icons.attachment,
  Icons.audiotrack,
  Icons.autorenew,
  Icons.av_timer,
  Icons.backspace,
  Icons.backup,
  Icons.battery_alert,
  Icons.battery_charging_full,
  Icons.battery_full,
  Icons.battery_std,
  Icons.battery_unknown,
  Icons.beach_access,
  Icons.beenhere,
  Icons.block,
  Icons.bluetooth,
  Icons.bluetooth_audio,
  Icons.bluetooth_connected,
  Icons.bluetooth_disabled,
  Icons.bluetooth_searching,
  Icons.blur_circular,
  Icons.blur_linear,
  Icons.blur_off,
  Icons.blur_on,
  Icons.book,
  Icons.bookmark,
  Icons.bookmark_border,
  Icons.border_all,
  Icons.border_bottom,
  Icons.border_clear,
  Icons.border_color,
  Icons.border_horizontal,
  Icons.border_inner,
  Icons.border_left,
  Icons.border_outer,
  Icons.border_right,
  Icons.border_style,
  Icons.border_top,
  Icons.border_vertical,
  Icons.branding_watermark,
  Icons.brightness_1,
  Icons.brightness_2,
  Icons.brightness_3,
  Icons.brightness_4,
  Icons.brightness_5,
  Icons.brightness_6,
  Icons.brightness_7,
  Icons.brightness_auto,
  Icons.brightness_high,
  Icons.brightness_low,
  Icons.brightness_medium,
  Icons.broken_image,
  Icons.brush,
  Icons.bubble_chart,
  Icons.bug_report,
  Icons.build,
  Icons.burst_mode,
  Icons.business,
  Icons.business_center,
  Icons.cached,
  Icons.cake,
  Icons.calendar_today,
  Icons.calendar_view_day,
  Icons.call,
  Icons.call_end,
  Icons.call_made,
  Icons.call_merge,
  Icons.call_missed,
  Icons.call_missed_outgoing,
  Icons.call_received,
  Icons.call_split,
  Icons.call_to_action,
  Icons.camera,
  Icons.camera_alt,
  Icons.camera_enhance,
  Icons.camera_front,
  Icons.camera_rear,
  Icons.camera_roll,
  Icons.cancel,
  Icons.card_giftcard,
  Icons.card_membership,
  Icons.card_travel,
  Icons.casino,
  Icons.cast,
  Icons.cast_connected,
  Icons.category,
  Icons.center_focus_strong,
  Icons.center_focus_weak,
  Icons.change_history,
  Icons.chat,
  Icons.chat_bubble,
  Icons.chat_bubble_outline,
  Icons.check,
  Icons.check_box,
  Icons.check_box_outline_blank,
  Icons.check_circle,
  Icons.check_circle_outline,
  Icons.chevron_left,
  Icons.chevron_right,
  Icons.child_care,
  Icons.child_friendly,
  Icons.chrome_reader_mode,
  Icons.class_,
  Icons.clear,
  Icons.clear_all,
  Icons.close,
  Icons.closed_caption,
  Icons.cloud,
  Icons.cloud_circle,
  Icons.cloud_done,
  Icons.cloud_download,
  Icons.cloud_off,
  Icons.cloud_queue,
  Icons.cloud_upload,
  Icons.code,
  Icons.collections,
  Icons.collections_bookmark,
  Icons.color_lens,
  Icons.colorize,
  Icons.comment,
  Icons.compare,
  Icons.compare_arrows,
  Icons.computer,
  Icons.confirmation_number,
  Icons.contact_mail,
  Icons.contact_phone,
  Icons.contacts,
  Icons.content_copy,
  Icons.content_cut,
  Icons.content_paste,
  Icons.control_point,
  Icons.control_point_duplicate,
  Icons.copyright,
  Icons.create,
  Icons.create_new_folder,
  Icons.credit_card,
  Icons.crop,
  Icons.crop_3_2,
  Icons.crop_5_4,
  Icons.crop_7_5,
  Icons.crop_16_9,
  Icons.crop_din,
  Icons.crop_free,
  Icons.crop_landscape,
  Icons.crop_original,
  Icons.crop_portrait,
  Icons.crop_rotate,
  Icons.crop_square,
  Icons.dashboard,
  Icons.data_usage,
  Icons.date_range,
  Icons.dehaze,
  Icons.delete,
  Icons.delete_forever,
  Icons.delete_outline,
  Icons.delete_sweep,
  Icons.departure_board,
  Icons.description,
  Icons.desktop_mac,
  Icons.desktop_windows,
  Icons.details,
  Icons.developer_board,
  Icons.developer_mode,
  Icons.device_hub,
  Icons.device_unknown,
  Icons.devices,
  Icons.devices_other,
  Icons.dialer_sip,
  Icons.dialpad,
  Icons.directions,
  Icons.directions_bike,
  Icons.directions_boat,
  Icons.directions_bus,
  Icons.directions_car,
  Icons.directions_railway,
  Icons.directions_run,
  Icons.directions_subway,
  Icons.directions_transit,
  Icons.directions_walk,
  Icons.disc_full,
  Icons.dns,
  Icons.do_not_disturb,
  Icons.do_not_disturb_alt,
  Icons.do_not_disturb_off,
  Icons.do_not_disturb_on,
  Icons.dock,
  Icons.domain,
  Icons.done,
  Icons.done_all,
  Icons.done_outline,
  Icons.donut_large,
  Icons.donut_small,
  Icons.drafts,
  Icons.drag_handle,
  Icons.drive_eta,
  Icons.dvr,
  Icons.edit,
  Icons.edit_attributes,
  Icons.edit_location,
  Icons.eject,
  Icons.email,
  Icons.enhanced_encryption,
  Icons.equalizer,
  Icons.error,
  Icons.error_outline,
  Icons.euro_symbol,
  Icons.ev_station,
  Icons.event,
  Icons.event_available,
  Icons.event_busy,
  Icons.event_note,
  Icons.event_seat,
  Icons.exit_to_app,
  Icons.expand_less,
  Icons.expand_more,
  Icons.explicit,
  Icons.explore,
  Icons.exposure,
  Icons.exposure_neg_1,
  Icons.exposure_neg_2,
  Icons.exposure_plus_1,
  Icons.exposure_plus_2,
  Icons.exposure_zero,
  Icons.extension,
  Icons.face,
  Icons.fast_forward,
  Icons.fast_rewind,
  Icons.fastfood,
  Icons.favorite,
  Icons.favorite_border,
  Icons.featured_play_list,
  Icons.featured_video,
  Icons.feedback,
  Icons.fiber_dvr,
  Icons.fiber_manual_record,
  Icons.fiber_new,
  Icons.fiber_pin,
  Icons.fiber_smart_record,
  Icons.file_download,
  Icons.file_upload,
  Icons.filter,
  Icons.filter_1,
  Icons.filter_2,
  Icons.filter_3,
  Icons.filter_4,
  Icons.filter_5,
  Icons.filter_6,
  Icons.filter_7,
  Icons.filter_8,
  Icons.filter_9,
  Icons.filter_9_plus,
  Icons.filter_b_and_w,
  Icons.filter_center_focus,
  Icons.filter_drama,
  Icons.filter_frames,
  Icons.filter_hdr,
  Icons.filter_list,
  Icons.filter_none,
  Icons.filter_tilt_shift,
  Icons.filter_vintage,
  Icons.find_in_page,
  Icons.find_replace,
  Icons.fingerprint,
  Icons.first_page,
  Icons.fitness_center,
  Icons.flag,
  Icons.flare,
  Icons.flash_auto,
  Icons.flash_off,
  Icons.flash_on,
  Icons.flight,
  Icons.flight_land,
  Icons.flight_takeoff,
  Icons.flip,
  Icons.flip_to_back,
  Icons.flip_to_front,
  Icons.folder,
  Icons.folder_open,
  Icons.folder_shared,
  Icons.folder_special,
  Icons.font_download,
  Icons.format_align_center,
  Icons.format_align_justify,
  Icons.format_align_left,
  Icons.format_align_right,
  Icons.format_bold,
  Icons.format_clear,
  Icons.format_color_fill,
  Icons.format_color_reset,
  Icons.format_color_text,
  Icons.format_indent_decrease,
  Icons.format_indent_increase,
  Icons.format_italic,
  Icons.format_line_spacing,
  Icons.format_list_bulleted,
  Icons.format_list_numbered,
  Icons.format_list_numbered_rtl,
  Icons.format_paint,
  Icons.format_quote,
  Icons.format_shapes,
  Icons.format_size,
  Icons.format_strikethrough,
  Icons.format_textdirection_l_to_r,
  Icons.format_textdirection_r_to_l,
  Icons.format_underlined,
  Icons.forum,
  Icons.forward,
  Icons.forward_5,
  Icons.forward_10,
  Icons.forward_30,
  Icons.four_k,
  Icons.free_breakfast,
  Icons.fullscreen,
  Icons.fullscreen_exit,
  Icons.functions,
  Icons.g_translate,
  Icons.gamepad,
  Icons.games,
  Icons.gavel,
  Icons.gesture,
  Icons.get_app,
  Icons.gif,
  Icons.golf_course,
  Icons.gps_fixed,
  Icons.gps_not_fixed,
  Icons.gps_off,
  Icons.grade,
  Icons.gradient,
  Icons.grain,
  Icons.graphic_eq,
  Icons.grid_off,
  Icons.grid_on,
  Icons.group,
  Icons.group_add,
  Icons.group_work,
  Icons.hd,
  Icons.hdr_off,
  Icons.hdr_on,
  Icons.hdr_strong,
  Icons.hdr_weak,
  Icons.headset,
  Icons.headset_mic,
  Icons.headset_off,
  Icons.healing,
  Icons.hearing,
  Icons.help,
  Icons.help_outline,
  Icons.high_quality,
  Icons.highlight,
  Icons.highlight_off,
  Icons.history,
  Icons.home,
  Icons.hot_tub,
  Icons.hotel,
  Icons.hourglass_empty,
  Icons.hourglass_full,
  Icons.http,
  Icons.https,
  Icons.image,
  Icons.image_aspect_ratio,
  Icons.import_contacts,
  Icons.import_export,
  Icons.important_devices,
  Icons.inbox,
  Icons.indeterminate_check_box,
  Icons.info,
  Icons.info_outline,
  Icons.input,
  Icons.insert_chart,
  Icons.insert_comment,
  Icons.insert_drive_file,
  Icons.insert_emoticon,
  Icons.insert_invitation,
  Icons.insert_link,
  Icons.insert_photo,
  Icons.invert_colors,
  Icons.invert_colors_off,
  Icons.iso,
  Icons.keyboard,
  Icons.keyboard_arrow_down,
  Icons.keyboard_arrow_left,
  Icons.keyboard_arrow_right,
  Icons.keyboard_arrow_up,
  Icons.keyboard_backspace,
  Icons.keyboard_capslock,
  Icons.keyboard_hide,
  Icons.keyboard_return,
  Icons.keyboard_tab,
  Icons.keyboard_voice,
  Icons.kitchen,
  Icons.label,
  Icons.label_important,
  Icons.label_outline,
  Icons.landscape,
  Icons.language,
  Icons.laptop,
  Icons.laptop_chromebook,
  Icons.laptop_mac,
  Icons.laptop_windows,
  Icons.last_page,
  Icons.launch,
  Icons.layers,
  Icons.layers_clear,
  Icons.leak_add,
  Icons.leak_remove,
  Icons.lens,
  Icons.library_add,
  Icons.library_books,
  Icons.library_music,
  Icons.lightbulb_outline,
  Icons.line_style,
  Icons.line_weight,
  Icons.linear_scale,
  Icons.link,
  Icons.link_off,
  Icons.linked_camera,
  Icons.list,
  Icons.live_help,
  Icons.live_tv,
  Icons.local_activity,
  Icons.local_airport,
  Icons.local_atm,
  Icons.local_bar,
  Icons.local_cafe,
  Icons.local_car_wash,
  Icons.local_convenience_store,
  Icons.local_dining,
  Icons.local_drink,
  Icons.local_florist,
  Icons.local_gas_station,
  Icons.local_grocery_store,
  Icons.local_hospital,
  Icons.local_hotel,
  Icons.local_laundry_service,
  Icons.local_library,
  Icons.local_mall,
  Icons.local_movies,
  Icons.local_offer,
  Icons.local_parking,
  Icons.local_pharmacy,
  Icons.local_phone,
  Icons.local_pizza,
  Icons.local_play,
  Icons.local_post_office,
  Icons.local_printshop,
  Icons.local_see,
  Icons.local_shipping,
  Icons.local_taxi,
  Icons.location_city,
  Icons.location_disabled,
  Icons.location_off,
  Icons.location_on,
  Icons.location_searching,
  Icons.lock,
  Icons.lock_open,
  Icons.lock_outline,
  Icons.looks,
  Icons.looks_3,
  Icons.looks_4,
  Icons.looks_5,
  Icons.looks_6,
  Icons.looks_one,
  Icons.looks_two,
  Icons.loop,
  Icons.loupe,
  Icons.low_priority,
  Icons.loyalty,
  Icons.mail,
  Icons.mail_outline,
  Icons.map,
  Icons.markunread,
  Icons.markunread_mailbox,
  Icons.maximize,
  Icons.memory,
  Icons.menu,
  Icons.merge_type,
  Icons.message,
  Icons.mic,
  Icons.mic_none,
  Icons.mic_off,
  Icons.minimize,
  Icons.missed_video_call,
  Icons.mms,
  Icons.mobile_screen_share,
  Icons.mode_comment,
  Icons.mode_edit,
  Icons.monetization_on,
  Icons.money_off,
  Icons.monochrome_photos,
  Icons.mood,
  Icons.mood_bad,
  Icons.more,
  Icons.more_horiz,
  Icons.more_vert,
  Icons.motorcycle,
  Icons.mouse,
  Icons.move_to_inbox,
  Icons.movie,
  Icons.movie_creation,
  Icons.movie_filter,
  Icons.multiline_chart,
  Icons.music_note,
  Icons.music_video,
  Icons.my_location,
  Icons.nature,
  Icons.nature_people,
  Icons.navigate_before,
  Icons.navigate_next,
  Icons.navigation,
  Icons.near_me,
  Icons.network_cell,
  Icons.network_check,
  Icons.network_locked,
  Icons.network_wifi,
  Icons.new_releases,
  Icons.next_week,
  Icons.nfc,
  Icons.no_encryption,
  Icons.no_sim,
  Icons.not_interested,
  Icons.not_listed_location,
  Icons.note,
  Icons.note_add,
  Icons.notification_important,
  Icons.notifications,
  Icons.notifications_active,
  Icons.notifications_none,
  Icons.notifications_off,
  Icons.notifications_paused,
  Icons.offline_bolt,
  Icons.offline_pin,
  Icons.ondemand_video,
  Icons.opacity,
  Icons.open_in_browser,
  Icons.open_in_new,
  Icons.open_with,
  Icons.outlined_flag,
  Icons.pages,
  Icons.pageview,
  Icons.palette,
  Icons.pan_tool,
  Icons.panorama,
  Icons.panorama_fish_eye,
  Icons.panorama_horizontal,
  Icons.panorama_vertical,
  Icons.panorama_wide_angle,
  Icons.party_mode,
  Icons.pause,
  Icons.pause_circle_filled,
  Icons.pause_circle_outline,
  Icons.payment,
  Icons.people,
  Icons.people_outline,
  Icons.perm_camera_mic,
  Icons.perm_contact_calendar,
  Icons.perm_data_setting,
  Icons.perm_device_information,
  Icons.perm_identity,
  Icons.perm_media,
  Icons.perm_phone_msg,
  Icons.perm_scan_wifi,
  Icons.person,
  Icons.person_add,
  Icons.person_outline,
  Icons.person_pin,
  Icons.person_pin_circle,
  Icons.personal_video,
  Icons.pets,
  Icons.phone,
  Icons.phone_android,
  Icons.phone_bluetooth_speaker,
  Icons.phone_forwarded,
  Icons.phone_in_talk,
  Icons.phone_iphone,
  Icons.phone_locked,
  Icons.phone_missed,
  Icons.phone_paused,
  Icons.phonelink,
  Icons.phonelink_erase,
  Icons.phonelink_lock,
  Icons.phonelink_off,
  Icons.phonelink_ring,
  Icons.phonelink_setup,
  Icons.photo,
  Icons.photo_album,
  Icons.photo_camera,
  Icons.photo_filter,
  Icons.photo_library,
  Icons.photo_size_select_actual,
  Icons.photo_size_select_large,
  Icons.photo_size_select_small,
  Icons.picture_as_pdf,
  Icons.picture_in_picture,
  Icons.picture_in_picture_alt,
  Icons.pie_chart,
  Icons.pie_chart_outlined,
  Icons.pin_drop,
  Icons.place,
  Icons.play_arrow,
  Icons.play_circle_filled,
  Icons.play_circle_outline,
  Icons.play_for_work,
  Icons.playlist_add,
  Icons.playlist_add_check,
  Icons.playlist_play,
  Icons.plus_one,
  Icons.poll,
  Icons.polymer,
  Icons.pool,
  Icons.portable_wifi_off,
  Icons.portrait,
  Icons.power,
  Icons.power_input,
  Icons.power_settings_new,
  Icons.pregnant_woman,
  Icons.present_to_all,
  Icons.print,
  Icons.priority_high,
  Icons.public,
  Icons.publish,
  Icons.query_builder,
  Icons.question_answer,
  Icons.queue,
  Icons.queue_music,
  Icons.queue_play_next,
  Icons.radio,
  Icons.radio_button_checked,
  Icons.radio_button_unchecked,
  Icons.rate_review,
  Icons.receipt,
  Icons.recent_actors,
  Icons.record_voice_over,
  Icons.redeem,
  Icons.redo,
  Icons.refresh,
  Icons.remove,
  Icons.remove_circle,
  Icons.remove_circle_outline,
  Icons.remove_from_queue,
  Icons.remove_red_eye,
  Icons.remove_shopping_cart,
  Icons.reorder,
  Icons.repeat,
  Icons.repeat_one,
  Icons.replay,
  Icons.replay_5,
  Icons.replay_10,
  Icons.replay_30,
  Icons.reply,
  Icons.reply_all,
  Icons.report,
  Icons.report_off,
  Icons.report_problem,
  Icons.restaurant,
  Icons.restaurant_menu,
  Icons.restore,
  Icons.restore_from_trash,
  Icons.restore_page,
  Icons.ring_volume,
  Icons.room,
  Icons.room_service,
  Icons.rotate_90_degrees_ccw,
  Icons.rotate_left,
  Icons.rotate_right,
  Icons.rounded_corner,
  Icons.router,
  Icons.rowing,
  Icons.rss_feed,
  Icons.rv_hookup,
  Icons.satellite,
  Icons.save,
  Icons.save_alt,
  Icons.scanner,
  Icons.scatter_plot,
  Icons.schedule,
  Icons.school,
  Icons.score,
  Icons.screen_lock_landscape,
  Icons.screen_lock_portrait,
  Icons.screen_lock_rotation,
  Icons.screen_rotation,
  Icons.screen_share,
  Icons.sd_card,
  Icons.sd_storage,
  Icons.search,
  Icons.security,
  Icons.select_all,
  Icons.send,
  Icons.sentiment_dissatisfied,
  Icons.sentiment_neutral,
  Icons.sentiment_satisfied,
  Icons.sentiment_very_dissatisfied,
  Icons.sentiment_very_satisfied,
  Icons.settings,
  Icons.settings_applications,
  Icons.settings_backup_restore,
  Icons.settings_bluetooth,
  Icons.settings_brightness,
  Icons.settings_cell,
  Icons.settings_ethernet,
  Icons.settings_input_antenna,
  Icons.settings_input_component,
  Icons.settings_input_composite,
  Icons.settings_input_hdmi,
  Icons.settings_input_svideo,
  Icons.settings_overscan,
  Icons.settings_phone,
  Icons.settings_power,
  Icons.settings_remote,
  Icons.settings_system_daydream,
  Icons.settings_voice,
  Icons.share,
  Icons.shop,
  Icons.shop_two,
  Icons.shopping_basket,
  Icons.shopping_cart,
  Icons.short_text,
  Icons.show_chart,
  Icons.shuffle,
  Icons.shutter_speed,
  Icons.signal_cellular_4_bar,
  Icons.signal_cellular_connected_no_internet_4_bar,
  Icons.signal_cellular_no_sim,
  Icons.signal_cellular_null,
  Icons.signal_cellular_off,
  Icons.signal_wifi_4_bar,
  Icons.signal_wifi_4_bar_lock,
  Icons.signal_wifi_off,
  Icons.sim_card,
  Icons.sim_card_alert,
  Icons.skip_next,
  Icons.skip_previous,
  Icons.slideshow,
  Icons.slow_motion_video,
  Icons.smartphone,
  Icons.smoke_free,
  Icons.smoking_rooms,
  Icons.sms,
  Icons.sms_failed,
  Icons.snooze,
  Icons.sort,
  Icons.sort_by_alpha,
  Icons.spa,
  Icons.space_bar,
  Icons.speaker,
  Icons.speaker_group,
  Icons.speaker_notes,
  Icons.speaker_notes_off,
  Icons.speaker_phone,
  Icons.spellcheck,
  Icons.star,
  Icons.star_border,
  Icons.star_half,
  Icons.stars,
  Icons.stay_current_landscape,
  Icons.stay_current_portrait,
  Icons.stay_primary_landscape,
  Icons.stay_primary_portrait,
  Icons.stop,
  Icons.stop_screen_share,
  Icons.storage,
  Icons.store,
  Icons.store_mall_directory,
  Icons.straighten,
  Icons.streetview,
  Icons.strikethrough_s,
  Icons.style,
  Icons.subdirectory_arrow_left,
  Icons.subdirectory_arrow_right,
  Icons.subject,
  Icons.subscriptions,
  Icons.subtitles,
  Icons.subway,
  Icons.supervised_user_circle,
  Icons.supervisor_account,
  Icons.surround_sound,
  Icons.swap_calls,
  Icons.swap_horiz,
  Icons.swap_horizontal_circle,
  Icons.swap_vert,
  Icons.swap_vertical_circle,
  Icons.switch_camera,
  Icons.switch_video,
  Icons.sync,
  Icons.sync_disabled,
  Icons.sync_problem,
  Icons.system_update,
  Icons.system_update_alt,
  Icons.tab,
  Icons.tab_unselected,
  Icons.table_chart,
  Icons.tablet,
  Icons.tablet_android,
  Icons.tablet_mac,
  Icons.tag_faces,
  Icons.tap_and_play,
  Icons.terrain,
  Icons.text_fields,
  Icons.text_format,
  Icons.text_rotate_up,
  Icons.text_rotate_vertical,
  Icons.text_rotation_angledown,
  Icons.text_rotation_angleup,
  Icons.text_rotation_down,
  Icons.text_rotation_none,
  Icons.textsms,
  Icons.texture,
  Icons.theaters,
  Icons.threed_rotation,
  Icons.threesixty,
  Icons.thumb_down,
  Icons.thumb_up,
  Icons.thumbs_up_down,
  Icons.time_to_leave,
  Icons.timelapse,
  Icons.timeline,
  Icons.timer,
  Icons.timer_3,
  Icons.timer_10,
  Icons.timer_off,
  Icons.title,
  Icons.toc,
  Icons.today,
  Icons.toll,
  Icons.tonality,
  Icons.touch_app,
  Icons.toys,
  Icons.track_changes,
  Icons.traffic,
  Icons.train,
  Icons.tram,
  Icons.transfer_within_a_station,
  Icons.transform,
  Icons.transit_enterexit,
  Icons.translate,
  Icons.trending_down,
  Icons.trending_flat,
  Icons.trending_up,
  Icons.trip_origin,
  Icons.tune,
  Icons.turned_in,
  Icons.turned_in_not,
  Icons.tv,
  Icons.unarchive,
  Icons.undo,
  Icons.unfold_less,
  Icons.unfold_more,
  Icons.update,
  Icons.usb,
  Icons.verified_user,
  Icons.vertical_align_bottom,
  Icons.vertical_align_center,
  Icons.vertical_align_top,
  Icons.vibration,
  Icons.video_call,
  Icons.video_label,
  Icons.video_library,
  Icons.videocam,
  Icons.videocam_off,
  Icons.videogame_asset,
  Icons.view_agenda,
  Icons.view_array,
  Icons.view_carousel,
  Icons.view_column,
  Icons.view_comfy,
  Icons.view_compact,
  Icons.view_day,
  Icons.view_headline,
  Icons.view_list,
  Icons.view_module,
  Icons.view_quilt,
  Icons.view_stream,
  Icons.view_week,
  Icons.vignette,
  Icons.visibility,
  Icons.visibility_off,
  Icons.voice_chat,
  Icons.voicemail,
  Icons.volume_down,
  Icons.volume_mute,
  Icons.volume_off,
  Icons.volume_up,
  Icons.vpn_key,
  Icons.vpn_lock,
  Icons.wallpaper,
  Icons.warning,
  Icons.watch,
  Icons.watch_later,
  Icons.wb_auto,
  Icons.wb_cloudy,
  Icons.wb_incandescent,
  Icons.wb_iridescent,
  Icons.wb_sunny,
  Icons.wc,
  Icons.web,
  Icons.web_asset,
  Icons.weekend,
  Icons.whatshot,
  Icons.widgets,
  Icons.wifi,
  Icons.wifi_lock,
  Icons.wifi_tethering,
  Icons.work,
  Icons.wrap_text,
  Icons.youtube_searched_for,
  Icons.zoom_in,
  Icons.zoom_out,
  Icons.zoom_out_map,
];
