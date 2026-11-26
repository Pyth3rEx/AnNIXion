{
  "group/distro-group" = {
    orientation = "horizontal";
    drawer = {
      transition-duration = 650;
      transition-left-to-right = true;
    };
    modules = [
      "custom/distro"
      "custom/terminal"
      "custom/code"
      "custom/obsidian"
      "custom/office"
      "custom/files"
      "custom/browser"
    ];
  };
  "group/storage" = {
    orientation = "horizontal";
    modules = [
      "disk"
      "memory"
    ];
  };
  "group/system" = {
    orientation = "horizontal";
    modules = [
      "temperature"
      "cpu"
    ];
  };
  "group/audio" = {
    orientation = "horizontal";
    drawer = {
      transition-duration = 650;
      transition-left-to-right = false;
    };
    modules = [
      "pulseaudio"
      "pulseaudio/slider"
      "pulseaudio#microphone"
    ];
  };
  "group/connections" = {
    orientation = "horizontal";
    drawer = {
      transition-duration = 500;
      transition-left-to-right = true;
    };
    modules = [
      "custom/network"
      "network#wired"
      "network#wifi"
      "bluetooth"
    ];
  };
  "group/tray-group" = {
    orientation = "horizontal";
    drawer = {
      transition-duration = 500;
      transition-left-to-right = false;
    };
    modules = [
      "custom/tray-arrow"
      "tray"
    ];
  };
}
