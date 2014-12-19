#!/bin/bash
############################################################

install_ruby() {
	mkdir /tmp/ruby 
	cd /tmp/ruby
	curl --progress ftp://ftp.ruby-lang.org/pub/ruby/2.0/ruby-2.0.0-p353.tar.gz | tar xz
	cd ruby-2.0.0-p353
	./configure --disable-install-rdoc
	make
	make install
}

install_libyaml() {
	mkdir /tmp/libyaml
	cd /tmp/libyaml
	curl --progress http://pyyaml.org/download/libyaml/yaml-0.1.4.tar.gz | tar xz
	cd yaml-0.1.4
	./configure
	make
	make install
}

if [[ "$(id -u)" != "0" ]]; then 
	echo "Must be run as root!"
	exit 1
fi

source ./install.conf
REPO_DIR=$(pwd)

ruby --version 
if [[ $? -ne 0 ]]; then
	install_ruby
fi

yum groupinstall "Development Tools"

# Note: I'm aware this will redo libyaml if you run it again after rebooting. Libyaml is small
# and fast to build and install, and I was just including this to make development of the 
# install scripts faster.
if [[ ! -d /tmp/libyaml ]]; then
	install_libyaml
fi

yum install -y wget curl curl-devel libxml2-devel libxslt-devel readline-devel glibc-devel openssl-devel zlib-devel openssh-server git-core postfix postgresql-devel libicu-devel

gem install bundler
cd $REPO_DIR
bundle install

cp lib/support/init.d/gitlab_ci_runner /etc/init.d/gitlab-ci-runner
sed -i "/APP_USER=/c\APP_USER=$(GLCIR_USER)" /etc/init.d/gitlab-ci-runner
sed -i "/APP_ROOT=/c\APP_ROOT=$(GLCIR_ROOT)" /etc/init.d/gitlab-ci-runner
chmod +x /etc/init.d/gitlab-ci-runner
chkconfig --level 3 gitlab-ci-runner on

cat <<'FINISH'
You may now set up the runner:
 bundle exec ./bin/setup

Afterward, start the runner by becoming root and running:
 service gitlab-ci-runner start

If your GitLab server is using self-signed certificate, you should run:
 ./git-remote-install-cert.sh https://<gitlab-server>/
FINISH
