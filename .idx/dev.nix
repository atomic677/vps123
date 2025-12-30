
   
   { pkgs, ... }: {
  channel = "stable-25.05";

  packages = with pkgs; [
    unzip
    openssh
    qemu_kvm
    qemu
    cloud-utils
    qemu_full
    nodejs
    docker
    docker-compose
  ];

  env = {
    EDITOR = "nano";
  };

  services.docker.enable = true;
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

