#!/bin/sh -ex

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
            if [ "$OS" = Windows_NT ]; then
                export LDFLAGS='-static -Wl,--allow-multiple-definition'
            fi
            sh -c "$build_command"
            $sudo tar -xf build/*.tgz -C /usr/local/zeek/lib/zeek/plugins
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

install_zeek_package brimdata/geoip-conn c9dd7f0f8d40573189b2ed2bae9fad478743cfdf
install_zeek_package salesforce/hassh 76a47abe9382109ce9ba530e7f1d7014a4a95209
install_zeek_package salesforce/ja3 421dd4f3616b533e6971bb700289c6bb8355e707
echo "@load policy/protocols/conn/community-id-logging" | $sudo tee -a /usr/local/zeek/share/zeek/site/local.zeek

#
# Create zip file.
#

mkdir -p zeek/bin zeek/lib/zeek zeek/share/zeek
cp zeekrunner$exe zeek/
cp /usr/local/zeek/bin/zeek$exe zeek/bin/
cp -R /usr/local/zeek/lib/zeek/plugins zeek/lib/zeek/
for d in base policy site builtin-plugins; do
    cp -R /usr/local/zeek/share/zeek/$d zeek/share/zeek/
done

$zip -r zeek-$RELEASE_TAG.$(go env GOOS)-$(go env GOARCH).zip zeek
