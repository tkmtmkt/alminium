#!/bin/sh

wget -q -O - http://pkg.jenkins-ci.org/debian/jenkins-ci.org.key | sudo apt-key add -
echo "deb http://pkg.jenkins-ci.org/debian binary/" > /etc/apt/sources.list.d/jenkins.list
apt-get -q2 update
apt-get -y install jenkins

sed -i 's/JENKINS_ARGS="--webroot/JENKINS_ARGS="--prefix=\/jenkins --webroot/' /etc/default/jenkins

service jenkins restart

# apache site 設定
if [ ! -f /etc/apache2/sites-available/jenkins ]
then
  cp etc/debian/jenkins.conf /etc/apache2/sites-available/jenkins
  a2ensite jenkins
fi
