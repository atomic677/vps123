
   
   { pkgs, ... }: {
  channel = "stable-23.05";

  packages = with pkgs; [
    unzip
    openssh
    qemu_kvm
    qemu
    cloud-utils
    qemu_full
  ];

  env = {
    EDITOR = "nano";
  };

  idx = {
    extensions = [
      "Dart-Code.flutter"
      "Dart-Code.dart-code"
    ];

    workspace = {
      onCreate = { };
      onStart = { };
    };

    previews = {
      enable = true;
    };
  };
}

