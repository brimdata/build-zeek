#!/bin/bash -ex

case $(uname) in
    Darwin|Linux)
        sudo=sudo
        zip=zip
        ;;
    *_NT-*)
        exe=.exe
        zip=/c/msys64/usr/bin/zip
        ;;
    *)
        echo "unknown OS: $(uname)" >&2
        exit 1
        ;;
esac

#
# Install Zeek packages.  We don't use zkg because it didn't work
# out-of-the-box in recent attempts and our package installation
# requirements are little more than copying scripts.  We already had
# the approach below working in our prior Windows port so we'll
# stick with it for now.
#

zkg_meta() {
    section=${1:?'section required'}
    option=${2:?'option required'}
    python3 <<EOF
import configparser
c = configparser.ConfigParser()
c.read('zkg.meta')
print(c.get('$section', '$option', fallback=''))
EOF
}

install_zeek_package() {
    github_repo=${1:?'github_repo required'}
    git_ref=${2:?'git_ref required'}
    package=${github_repo#*/}
    mkdir $package
    (
        export PATH=/usr/local/zeek/bin:$PATH
        cd $package
        curl -sL https://github.com/$github_repo/tarball/$git_ref |
            tar -xzf - --strip-components 1

        script_dir=$(zkg_meta package script_dir)
        $sudo cp -r "$script_dir" /usr/local/zeek/share/zeek/site/$package/

        build_command=$(zkg_meta package build_command)
        if [ "$build_command" ]; then
            echo "building plugins not currently supported"
            exit 1
        fi

        test_command=$(zkg_meta package test_command)
        if [ "$test_command" ]; then
            # Btest fails without explanation on the GitHub Actions
            # Windows runners, so skip tests there.
            if [ "$GITHUB_ACTIONS" != true -o "$OS" != Windows_NT ]; then
               sh -c "$test_command"
            fi
        fi

        echo "@load $package" | $sudo tee -a /usr/local/zeek/share/zeek/site/local.zeek
    )
    rm -r $package
}

$sudo pip3 install btest wheel

install_zeek_package brimdata/geoip-conn 47d53a11921f4932b3076fee5fc50493b108764f
install_zeek_package salesforce/hassh 76a47abe9382109ce9ba530e7f1d7014a4a95209
install_zeek_package salesforce/ja3 421dd4f3616b533e6971bb700289c6bb8355e707
echo "@load policy/protocols/conn/community-id-logging" | $sudo tee -a /usr/local/zeek/share/zeek/site/local.zeek

# Work around https://github.com/zeek/zeek/issues/3534 on Windows
[[ $(uname) =~ "NT" ]] &&
  sed -i \
    -e 's|^@load protocols/ssh/interesting-hostnames|#\0 # https://github.com/zeek/zeek/issues/3534 workaround|' \
    -e 's|^@load frameworks/files/detect-MHR|#\0 # https://github.com/zeek/zeek/issues/3534 workaround|' \
    /usr/local/zeek/share/zeek/site/local.zeek

#
# Create zip file.
#

mkdir -p zeek/bin zeek/lib/zeek zeek/share/zeek
cp zeekrunner$exe zeek/
cp /usr/local/zeek/bin/zeek$exe zeek/bin/
for d in base policy site builtin-plugins; do
    cp -R /usr/local/zeek/share/zeek/$d zeek/share/zeek/
done

$zip -r zeek-$(git describe --always --tags).$(go env GOOS)-$(go env GOARCH).zip zeek
