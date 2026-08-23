{
  stdenv,
  lib,
  fetchurl,

  glibc,
  atk,
  libayatana-appindicator,
  ayatana-ido,
  libayatana-indicator,
  cairo,
  curl,
  glib,
  dbus,
  libdbusmenu,
  libepoxy,
  fontconfig,
  libgcc,
  gtk3,
  gdk-pixbuf,
  harfbuzz,
  webkitgtk_4_1,
  temurin-jre-bin-17,
  nspr,
  nss,
  pango,
  libpcap,
  libsoup_3,
  tpm2-tss,
  zlib,

  nftables,

  dpkg,
  patchelf,
  autoPatchelfHook,
}:

let
  version = "2026.7.1343.0";
  sources = {
    x86_64-linux = fetchurl {
      url = "https://downloads.cloudflareclient.com/v1/download/resolute-intel/version/${version}";
      hash = "sha256-LDDl05szv2b4TVuL2x9bzKXEm1A9y2J7VnwYbm6OK6o=";
    };
  };
in
stdenv.mkDerivation {
  pname = "cloudflare-warp";
  inherit version;

  src = sources.${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

  buildInputs = [
    glibc
    atk
    libayatana-appindicator
    ayatana-ido
    libayatana-indicator
    cairo
    curl
    glib
    dbus
    libdbusmenu
    libepoxy
    fontconfig
    libgcc
    gtk3
    gdk-pixbuf
    harfbuzz
    webkitgtk_4_1
    temurin-jre-bin-17
    nspr
    nss
    pango
    libpcap
    libsoup_3
    tpm2-tss
    zlib

    nftables
  ];

  nativeBuildInputs = [
    dpkg

    patchelf
    autoPatchelfHook
  ];

  phases = [ "unpackPhase" "installPhase" "fixupPhase" ];

  unpackPhase = ''
    runHook preUnpack

    dpkg-deb -x "$src" data
    cd data

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    recover_extglob=$(shopt -p extglob || true)
    shopt -s extglob

    fix_path() {
      local normalized_path=''${1##.?(/)}
      echo "''${normalized_path##usr?(\/)}"
    }
    fix_path_str=$(declare -f fix_path)

    find . -type d -exec bash -c $'
      shopt -s extglob

      '"$fix_path_str"$'

      fixed_path=$(fix_path "{}")
      [[ -z $fixed_path ]] && exit

      install -d "'"$out"$'/$fixed_path"
    ' _ \;

    find . -type f -exec bash -c $'
      shopt -s extglob

      '"$fix_path_str"$'

      fixed_path=$(fix_path "{}")

      mv "{}" "'"$out"$'/$fixed_path"

      read -r -n 4 header < "'"$out"$'/$fixed_path"
      [[ $header = $\'\\x7fELF\' ]] && mode=775 || mode=664

      chmod "$mode" "'"$out"$'/$fixed_path"
    ' _ \;

    ln -s ../lib/warp/warp-taskbar "$out/bin/warp-taskbar"
    ln -s ../../../../../lib/warp/data/flutter_assets/assets/svgs/zero-trust-orange.svg "$out/share/icons/hicolor/scalable/apps/zero-trust-orange.svg"

    $recover_extglob

    runHook postInstall
  '';

  preFixup = ''
    patchelf --replace-needed libpcap.so.0.8 libpcap.so.1 "$out/bin/warp-dex"
    patchelf --add-needed librust_bridge.so "$out/lib/warp/lib/libflutter_linux_gtk.so"

    addAutoPatchelfSearchPath "$out/lib/warp/lib"
  '';

  postFixup = ''
    substituteInPlace "$out/lib/systemd/system/warp-svc.service" --replace-fail ExecStart=/bin/warp-svc "ExecStart=$out/bin/warp-svc"$'\nBindReadOnlyPaths=${nftables}/bin/nft:/usr/sbin/nft'
    substituteInPlace "$out/share/systemd/user/warp-taskbar.service" --replace-fail ExecStart=/bin/warp-taskbar "ExecStart=$out/bin/warp-taskbar"
    substituteInPlace "$out/share/dbus-1/services/com.cloudflare.WarpTaskbar.service" --replace-fail Exec=/bin/warp-taskbar "Exec=$out/bin/warp-taskbar"
    substituteInPlace "$out/share/applications/com.cloudflare.warp.desktop" --replace-fail Exec=/bin/warp-cli "Exec=$out/bin/warp-cli"
    substituteInPlace "$out/share/applications/com.cloudflare.WarpTaskbar.desktop" --replace-fail Exec=/bin/warp-taskbar "Exec=$out/bin/warp-taskbar"
  '';

  meta = {
    description = "Cloudflare Warp Client";
    homepage = "https://1.1.1.1";
    license = lib.licenses.unfree;
    maintainers = [ (import ../../maintainers.nix).nightspacec ];
    platforms = [ "x86_64-linux" ];
  };
}
