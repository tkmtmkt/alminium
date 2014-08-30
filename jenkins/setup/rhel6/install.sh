#!/bin/sh

wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins-ci.org/redhat/jenkins.repo
rpm --import http://pkg.jenkins-ci.org/redhat/jenkins-ci.org.key
yum install -y jenkins 
yum install -y java-1.7.0-openjdk-devel
rpm -vi --force inst-script/rhel6/mod_auth_mysql-3.0.0-11.el6.1.redmine.x86_64.rpm

#CHK=`grep "dport 8080" /etc/sysconfig/iptables`
#if [ "$CHK" = '' ]
#then
#  RULENUM=`iptables-save |grep INPUT |grep -n "dport 22"|awk -F : '{print $1}'`
#  iptables -I  INPUT ${RULENUM} -p tcp -m state --state NEW -m tcp --dport 8080 -j ACCEPT
#  iptables-save > /etc/sysconfig/iptables
#fi

if [ ! -d /var/lib/jenkins/persona ]
then
  git clone https://github.com/okamototk/jenkins-persona-hudmi /var/lib/jenkins/persona
fi

if [ ! -f /etc/httpd/conf.d/jenkins.conf ]
then
  cp etc/rhel6/jenkins.conf /etc/httpd/conf.d/jenkins.conf
fi
 
sed -i 's/JENKINS_ARGS=""/JENKINS_ARGS="--prefix=\/jenkins"/' /etc/sysconfig/jenkins

if [ ! -f /var/lib/jenkins/plugins ]
then
  mkdir /var/lib/jenkins/plugins
  chown jenkins.jenkins /var/lib/jenkins/plugins
fi

service jenkins start

RET=-1
until  [ "$RET" -eq "0" ]
do
  sleep 3
  wget --no-proxy -O $INSTALL_DIR/bin/jenkins-cli.jar http://localhost:8080/jenkins/jnlpJars/jenkins-cli.jar
  RET=$?
done

wget -O /tmp/default.js http://updates.jenkins-ci.org/update-center.json
 
# remove first and last line javascript wrapper
sed '1d;$d' /tmp/default.js > /tmp/default.json
  
# Now push it to the update URL
curl --noproxy localhost -X POST -H "Accept: application/json" -d @/tmp/default.json http://localhost:8080/jenkins/updateCenter/byId/default/postBack --verbose

if [ x"$http_proxy" != x"" ]
then
  # set proxy. sorry IPv4 only and user:pass not supported...
  proxyuser=`echo $http_proxy | sed -n 's/.*:\/\/\([a-zA-Z0-9]*\):.*/\1/p'`
  proxypass=`echo $http_proxy | sed -n 's/.*:\/\/[a-zA-Z0-9]*:\([a-zA-Z0-9:]*\)\@.*/\1/p'`
  echo 
  echo proxyuser=$proxyuser
  echo proxypass=$proxypass

  if [ x"$proxyuser" != x"" ]
  then
    http_proxy=`echo $http_proxy | sed "s/$proxyuser:$proxypass\@//"`
  fi

  proxyserver=`echo $http_proxy | cut -d':' -f2 | sed 's/\/\///g'`
  proxyport=`echo $http_proxy | cut -d':' -f3 | sed 's/\///g'`
  echo proxyserver=$proxyserver
  echo proxyport=$proxyport

  curl --noproxy localhost -X POST --data "json={\"name\": \"$proxyserver\", \"port\": \"$proxyport\", \"userName\": \"$proxyuser\", \"password\": \"$proxypass\", \"noProxyHost\": \"\"}" http://localhost:8080/jenkins/pluginManager/proxyConfigure --verbose
  RET=$?
  if [ "$RET" -ne "0" ]
  then
    echo "proxy setting for jenkins fail"
    exit 1
  fi
  #service jenkins restart
fi

# jenkinsプラグインファイルをカレントディレクトリにダウンロードしてから
# インストールしているようなので、redmineがインストールできない。
# 暫定回避策としてtmpディレクトリ内に移動してから処理する。
mkdir tmp
pushd tmp
RET=-1
until  [ "$RET" -eq "0" ]
do
  sleep 3
  java -jar $INSTALL_DIR/bin/jenkins-cli.jar -s http://localhost:8080/jenkins/ install-plugin reverse-proxy-auth-plugin
  RET=$?
done

java -jar $INSTALL_DIR/bin/jenkins-cli.jar -s http://localhost:8080/jenkins/ install-plugin reverse-proxy-auth-plugin
java -jar $INSTALL_DIR/bin/jenkins-cli.jar -s http://localhost:8080/jenkins/ install-plugin persona
java -jar $INSTALL_DIR/bin/jenkins-cli.jar -s http://localhost:8080/jenkins/ install-plugin git
java -jar $INSTALL_DIR/bin/jenkins-cli.jar -s http://localhost:8080/jenkins/ install-plugin redmine
java -jar $INSTALL_DIR/bin/jenkins-cli.jar -s http://localhost:8080/jenkins/ install-plugin dashboard-view
popd
rm -rf tmp

sleep 10

if [ ! -f /var/lib/jenkins/config.xml ]
then
  cp jenkins/config.xml /var/lib/jenkins/config.xml
fi

java -jar $INSTALL_DIR/bin/jenkins-cli.jar -s http://localhost:8080/jenkins/ restart

