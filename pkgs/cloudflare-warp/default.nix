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

    normalize_path() {
      local remain=$1

      local normalized
      if [[ $remain == /* ]]; then
        normalized=/
        remain=''${remain#/}
      else
        normalized=
      fi

      while [[ -n $remain ]]; do
        [[ $remain == /* ]] && return 1

        if [[ $remain == ./* || $remain == . ]]; then
          remain=''${remain##.?(/)}
        elif [[ $remain == ../* || $remain == .. ]]; then
          [[ $normalized == / ]] && return 1

          if [[ $normalized == */../ || $normalized == ../ || -z $normalized ]]; then
            normalized=$normalized../
          elif [[ $normalized == */*/ ]]; then
            normalized=''${normalized%/*/}/
          else
            normalized=
          fi

          remain=''${remain##..?(/)}
        elif [[ $remain == */* ]]; then
          normalized=$normalized''${remain%%/*}/
          remain=''${remain#*/}
        else
          normalized=$normalized$remain/
          remain=
        fi
      done

      [[ -z $normalized ]] && normalized=./
      [[ $normalized != / ]] && normalized=''${normalized%/}
      echo "$normalized"
    }
    normalize_path_str=$(declare -f normalize_path)

    join_path() {
      local prefix suffix ret

      prefix=$(normalize_path "$1")
      ret=$?
      [[ $ret != 0 ]] && return "$ret"

      suffix=$(normalize_path "$2")
      ret=$?
      [[ $ret != 0 ]] && return "$ret"

      [[ $suffix == /* ]] && return 1

      local path
      if [[ $prefix == / ]]; then
        path=$(normalize_path "/$suffix")
      else
        path=$(normalize_path "$prefix/$suffix")
      fi
      ret=$?
      [[ $ret != 0 ]] && return "$ret"

      echo "$path"
    }
    join_path_str=$(declare -f join_path)

    relative_path() {
      local target base ret

      target=$(normalize_path "$1")
      ret=$?
      [[ $ret != 0 ]] && return "$ret"

      base=$(normalize_path "$2")
      ret=$?
      [[ $ret != 0 ]] && return "$ret"

      [[ $base == /* && $target == /* || $base != /* && $target != /* ]] || return 1

      while [[ -n $base && -n $target ]]; do
        local base_next=''${base%%/*}
        local target_next=''${target%%/*}
        if [[ $base_next != $target_next ]]; then
          break
        fi

        if [[ $base != */* ]]; then
          base=
        else
          base=''${base#*/}
        fi
        if [[ $target != */* ]]; then
          target=
        else
          target=''${target#*/}
        fi
      done

      local relative=
      while [[ -n $base ]]; do
        local base_next=''${base%%/*}
        [[ $base_next == .. ]] && return 1

        relative=$relative../

        if [[ $base != */* ]]; then
          base=
        else
          base=''${base#*/}
        fi
      done

      echo "$(join_path "$relative" "$target")"
    }
    relative_path_str=$(declare -f relative_path)

    follow_link() {
      local original link target ret

      original=$(normalize_path "$1")
      ret=$?
      [[ $ret != 0 ]] && return "$ret"

      link=$(normalize_path "$2")
      ret=$?
      [[ $ret != 0 ]] && return "$ret"

      target=$(normalize_path "$3")
      ret=$?
      [[ $ret != 0 ]] && return "$ret"

      local relative
      relative=$(relative_path "$original" "$link")
      ret=$?
      [[ $ret != 0 ]] && return "$ret"

      if [[ $relative == ../* || $relative == .. ]]; then
        echo "$original"
        return 0
      fi

      echo "$(join_path "$target" "$relative")"
    }
    follow_link_str=$(declare -f follow_link)


    find . -type d -exec bash -c $'
      shopt -s extglob

      '"$normalize_path_str"$'
      '"$join_path_str"$'
      '"$relative_path_str"$'
      '"$follow_link_str"$'

      final_path=$(follow_link "{}" usr .)

      mkdir -m 755 -p "$(join_path "'"$out"$'" "$final_path")"
    ' _ \;

    find . -type f -exec bash -c $'
      shopt -s extglob

      '"$normalize_path_str"$'
      '"$join_path_str"$'
      '"$relative_path_str"$'
      '"$follow_link_str"$'

      final_path=$(follow_link "{}" usr .)

      mv "{}" "'"$out"$'/$final_path"

      read -r -n 4 header < "'"$out"$'/$final_path"
      [[ $header = $\'\\x7fELF\' ]] && mode=755 || mode=644

      chmod "$mode" "'"$out"$'/$final_path"
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
    substituteInPlace "$out/lib/systemd/system/warp-svc.service" --replace-fail ExecStart=/bin/warp-svc "ExecStart=$out/bin/warp-svc"$'\n'"BindReadOnlyPaths=${nftables}/bin/nft:/usr/sbin/nft"
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
