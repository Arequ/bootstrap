#!/bin/bash
# Not using bolt or anything because personal devices..
# MDM-less bootstrap for my personal taste.

install_latest_git_release () {
    # Fetch and install latest release of specified repo/file.
    RELEASES_URL=$1
    JSON_OUT=$( curl -s $LATEST_URL )
    DL_URL=$(grep -o "https://github.com/\w\+/\w\+/releases/\S\+/$2" <<< $JSON_OUT | head -n 1 || echo "Did not find pattern, check URL. " | sys.exit 1)
    # get just filename from slug.
    FILE_NAME=${DL_URL##*/}
    curl -L $DL_URL -o /tmp/$FILE_NAME
    sudo installer -pkg /tmp/$FILE_NAME -target /
}

main () {
    # If it doesn't happen more than once, it's not a function.
    # https://scriptingosx.com/2020/02/getting-the-current-user-in-macos-update/
    LOGGED_IN_USER=$( scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

    echo "Enter admin password when prompted..."
    sudo echo "Proceeding..." || echo "Incorrect password bruh."

    # I want to install AutoPkg which will install Puppet, Git, Python3 and munkitools for munki recipes
    # (although I'm gonna build a munkitools install recipe so that this the loop isn't necessary and while, cuz I can't find one)
    # the loop is excessive now, it's put together with scaling in mind..

    declare -a AUTOPKG=( 'https://api.github.com/repos/autopkg/autopkg/releases/latest,autopkg-\d.\d.\d.pkg' )
    declare -a MUNKI=( 'https://api.github.com/repos/munki/munki/releases,munkitools-\d.\d.\d.\d\{4\}.pkg' )
    declare -a PKGS_JOIN=($AUTOPKG $MUNKI)
    for pkg in ${PKGS_JOIN[@]}; do
        url=$(cut -f1 -d, <<< $pkg)
        regexp=$(cut -f2 -d, <<< $pkg)
        install_latest_git_release $url $regexp
    done

    # autopkg stuff
    /usr/local/bin/autopkg repo-add https://github.com/Arequ/autopkg_recipes
    /usr/local/bin/autopkg run Puppet-Agent.install.recipe
    # I could keep installing things with autopkg but we wanna see munki, right?
    # install homebrew
    sudo -u $LOGGED_IN_USER /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # install git
    sudo -u $LOGGED_IN_USER /bin/bash -c "/usr/local/bin/brew install git"
    # get masterless puppet ready
    mkdir -p /var/cache/
    mkdir -p /etc/puppetlabs/r10k

    cat > /etc/puppetlabs/r10k/r10k.yaml <<EOF
:cachedir: /var/cache/r10k
:sources:
    :control:
        :remote: 'https://github.com/Arequ/pe_control_repo.git'
        :basedir: '/etc/puppetlabs/code/environments'
EOF

    # disable warnings about blank vars when performing hiera lookups
    sed -i '$a\disable_warnings = undefined_variables' /etc/puppetlabs/puppet/puppet.conf
    # so we can deploy from a git repo
    /opt/puppetlabs/puppet/bin/gem install r10k
    /opt/puppetlabs/puppet/bin/gem install hiera-eyaml
    # bam, right from the git repo
    /opt/puppetlabs/puppet/bin/r10k deploy environment production --puppetfile --verbose
    # lets pass the fact that we want to use to determine our role.
    FACTER_username=$LOGGED_IN_USER /opt/puppetlabs/bin/puppet apply /etc/puppetlabs/code/environments/production/manifests/entry.pp --verbose
}

main





