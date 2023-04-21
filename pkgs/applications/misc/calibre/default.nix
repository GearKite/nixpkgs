{ lib
, stdenv
, fetchurl
, cmake
, fetchpatch
, fontconfig
, hunspell
, hyphen
, icu
, imagemagick
, libjpeg
, libmtp
, libpng
, libstemmer
, libuchardet
, libusb1
, pkg-config
, podofo
, poppler_utils
, python3Packages
, qmake
, qtbase
, qtwayland
, removeReferencesTo
, speechd
, sqlite
, wrapQtAppsHook
, xdg-utils
, wrapGAppsHook
, unrarSupport ? false
}:

stdenv.mkDerivation rec {
  pname = "calibre";
  version = "6.16.0";

  src = fetchurl {
    url = "https://download.calibre-ebook.com/${version}/calibre-${version}.tar.xz";
    hash = "sha256-2Lhp9PBZ19svq26PoldJ1H8tmt95MwY0l7+g6mPUvFI=";
  };

  # https://sources.debian.org/patches/calibre/${version}+dfsg-1
  patches = [
    #  allow for plugin update check, but no calibre version check
    (fetchpatch {
      name = "0001-only-plugin-update.patch";
      url = "https://raw.githubusercontent.com/debian-calibre/calibre/debian/${version}-1/debian/patches/0001-only-plugin-update.patch";
      hash = "sha256-uL1mSjgCl5ZRLbSuKxJM6XTfvVwog70F7vgKtQzQNEQ=";
    })
    (fetchpatch {
      name = "0007-Hardening-Qt-code.patch";
      url = "https://raw.githubusercontent.com/debian-calibre/calibre/debian/${version}-1/debian/patches/0007-Hardening-Qt-code.patch";
      hash = "sha256-9P1kGrQbWAWDzu5EUiQr7TiCPHRWUA8hxPpEvFpK20k=";
    })
  ]
  ++ lib.optional (!unrarSupport) ./dont_build_unrar_plugin.patch;

  prePatch = ''
    sed -i "s@\[tool.sip.project\]@[tool.sip.project]\nsip-include-dirs = [\"${python3Packages.pyqt6}/${python3Packages.python.sitePackages}/PyQt6/bindings\"]@g" \
      setup/build.py

    # Remove unneeded files and libs
    rm -rf src/odf resources/calibre-portable.*
  '';

  dontUseQmakeConfigure = true;
  dontUseCmakeConfigure = true;

  nativeBuildInputs = [
    cmake
    pkg-config
    qmake
    removeReferencesTo
    wrapGAppsHook
    wrapQtAppsHook
  ];

  buildInputs = [
    fontconfig
    hunspell
    hyphen
    icu
    imagemagick
    libjpeg
    libmtp
    libpng
    libstemmer
    libuchardet
    libusb1
    podofo
    poppler_utils
    qtbase
    qtwayland
    sqlite
    xdg-utils
  ] ++ (
    with python3Packages; [
      (apsw.overrideAttrs (oldAttrs: {
        setupPyBuildFlags = [ "--enable=load_extension" ];
      }))
      beautifulsoup4
      css-parser
      cssselect
      python-dateutil
      dnspython
      faust-cchardet
      feedparser
      html2text
      html5-parser
      lxml
      markdown
      mechanize
      msgpack
      netifaces
      pillow
      pychm
      pyqt-builder
      pyqt6
      python
      regex
      sip
      setuptools
      speechd
      zeroconf
      jeepney
      pycryptodome
      # the following are distributed with calibre, but we use upstream instead
      odfpy
    ] ++ lib.optionals (lib.lists.any (p: p == stdenv.hostPlatform.system) pyqt6-webengine.meta.platforms) [
      # much of calibre's functionality is usable without a web
      # browser, so we enable building on platforms which qtwebengine
      # does not support by simply omitting qtwebengine.
      pyqt6-webengine
    ] ++ lib.optional (unrarSupport) unrardll
  );

  installPhase = ''
    runHook preInstall

    export HOME=$TMPDIR/fakehome
    export POPPLER_INC_DIR=${poppler_utils.dev}/include/poppler
    export POPPLER_LIB_DIR=${poppler_utils.out}/lib
    export MAGICK_INC=${imagemagick.dev}/include/ImageMagick
    export MAGICK_LIB=${imagemagick.out}/lib
    export FC_INC_DIR=${fontconfig.dev}/include/fontconfig
    export FC_LIB_DIR=${fontconfig.lib}/lib
    export PODOFO_INC_DIR=${podofo.dev}/include/podofo
    export PODOFO_LIB_DIR=${podofo.lib}/lib
    export XDG_DATA_HOME=$out/share
    export XDG_UTILS_INSTALL_MODE="user"

    ${python3Packages.python.pythonForBuild.interpreter} setup.py install --root=$out \
      --prefix=$out \
      --libdir=$out/lib \
      --staging-root=$out \
      --staging-libdir=$out/lib \
      --staging-sharedir=$out/share

    PYFILES="$out/bin/* $out/lib/calibre/calibre/web/feeds/*.py
      $out/lib/calibre/calibre/ebooks/metadata/*.py
      $out/lib/calibre/calibre/ebooks/rtf2xml/*.py"

    sed -i "s/env python[0-9.]*/python/" $PYFILES
    sed -i "2i import sys; sys.argv[0] = 'calibre'" $out/bin/calibre

    mkdir -p $out/share
    cp -a man-pages $out/share/man

    runHook postInstall
  '';

  # Wrap manually
  dontWrapQtApps = true;
  dontWrapGApps = true;

  # Remove some references to shrink the closure size. This reference (as of
  # 2018-11-06) was a single string like the following:
  #   /nix/store/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-podofo-0.9.6-dev/include/podofo/base/PdfVariant.h
  preFixup = ''
    remove-references-to -t ${podofo.dev} \
      $out/lib/calibre/calibre/plugins/podofo.so

    for program in $out/bin/*; do
      wrapProgram $program \
        ''${qtWrapperArgs[@]} \
        ''${gappsWrapperArgs[@]} \
        --prefix PYTHONPATH : $PYTHONPATH \
        --prefix PATH : ${poppler_utils.out}/bin
    done
  '';

  disallowedReferences = [ podofo.dev ];

  meta = with lib; {
    homepage = "https://calibre-ebook.com";
    description = "Comprehensive e-book software";
    longDescription = ''
      calibre is a powerful and easy to use e-book manager. Users say it’s
      outstanding and a must-have. It’ll allow you to do nearly everything and
      it takes things a step beyond normal e-book software. It’s also completely
      free and open source and great for both casual users and computer experts.
    '';
    license = with licenses; if unrarSupport then unfreeRedistributable else gpl3Plus;
    maintainers = with maintainers; [ pSub AndersonTorres ];
    platforms = platforms.linux;
  };
}
