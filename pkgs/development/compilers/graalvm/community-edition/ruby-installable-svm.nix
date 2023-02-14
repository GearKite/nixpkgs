{ lib
, stdenv
, graalvmCEPackages
, openssl
, javaVersion
, musl
, src
, version
, llvm-installable-svm
}:

graalvmCEPackages.buildGraalvmProduct rec {
  inherit src javaVersion version;
  product = "ruby-installable-svm";

  extraBuildInputs = [
    llvm-installable-svm
    openssl
  ];

  preFixup = ''
    patchelf $out/languages/ruby/lib/mri/openssl.so \
      --replace-needed libssl.so.10 libssl.so \
      --replace-needed libcrypto.so.10 libcrypto.so
  '';

  installCheckPhase = ''
    echo "Testing TruffleRuby"
    # Hide warnings about wrong locale
    export LANG=C
    export LC_ALL=C
    $out/bin/ruby -e 'puts(1 + 1)'
    echo '1 + 1' | $out/bin/irb
  '';
}
