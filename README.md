# nexus3-ssl
This Dockerfile provide a Nexus 3.5.2 Repository Manager with ssl only support.  
So all http traffic will be redirected to https immediatelly.

## Requisite
- ssl private key named cert.key.pem  
- ssl fullchain certificate named fullchain.pem

Just provide this in the directory wich is passed to the docker damon at build time.

To obtain a ssl certificate you can use [Certbot](https://certbot.eff.org/#debianstretch-other)  

!!Attention!!  
You have to rebuild the image with the renewed certifiacte every 90 days! But no data will be lost if you create a volume and map it to the nexus-data (sonatype-work) directory as shown bellow.

## Build the image
To build the image:
```
docker build --rm=true --tag=avensio/nexus3-ssl .
or
docker build --rm=true --tag=avensio/nexus3-ssl --build-arg SSL_STOREPASS=changeit123123
```
You can pass the following arguments to the build:  
- SSL_STOREPASS       (default: changeit)
- NEXUS_VERSION       (default: 3.5.2-01)
- NEXUS_DOWNLOAD_URL  (default: https://download.sonatype.com/nexus/3/nexus-${NEXUS_VERSION}-unix.tar.gz)

Possibilities:
- pass no args
- pass SSL_STOREPASS
- pass NEXUS_VERSION (only 3.x.x)

If Nexus 4 becomes available or you want to use Nexus 2.x.x:  
- pass NEXUS_VERSION and NEXUS_DOWNLOAD_URL

And finally you can pass all the args together.

## Create volume to persist the sonatype-work directory (see symlink at the bottom of the Dockerfile)
```
docker volume create --name nexus-data
```

## Run the image with the recently created volume mapped to the /nexus-data directory (sonatype-work --> see symlink mentioned above)
```
docker run -d --restart=always -p 8081:8081 -p 8082:8082 -p 8083:8083 -p 8443:8443 -v nexus-data:/nexus-data avensio/nexus3-ssl
```
- access UI --> http://hostname.tld:8081 or https://hostname.tld:8443 (if you choose http it will redirect to https)
- default credentials --> username: admin  
                          password: admin123

## Add registrys to Nexus 3
Follow the blog posts to Nexus 3 on [this](http://codeheaven.io) website to configure a Maven, NPM and Docker registry.

# NPM
## Download from NPM Registry
Add the following line to your ~/.npmrc to gain Download access to the registry: 
```
registry=http://hostname.tld:8081/repository/npm-group/_auth=YWRtaW46YWRtaW4xMjM= 
```
where the value of _auth is a base64 representation of your credentials. You can get this string with: 
```
echo -n 'admin:admin123' | openssl base64 
``` 
Now **npm install** will now download also from the new repository! 
## Upload to NPM Registry
If you want to publish(upload) a npm project to the registry, add the following into you package.json of the target project
```
  "publishConfig": {
    "registry": "http://hostname.tld:8081/repository/npm-private/"
  }
```
now you can just **npm pulish** your project
# Docker 
## Download image from Docker registry (port 8082 -> download) 
```
docker pull hostname.tld:8082/nexus3-ssl
```

## For uploading an image, first login to registry 
```
docker login -u admin -p admin123 hostname.tld:8082   
docker login -u admin -p admin123 hostname.tld:8083 
```

## Upload image to Docker registry (port 8083 -> upload) 
First you need to tag the build. After that you can push it to the registry:
```
docker tag nexus3-ssl hostname.tld:8083/nexus3-ssl 
docker push hostname.tld:8083/nexus3-ssl 
``` 

# Maven 
## Download artifacts from the maven registry 
If you only want to download from the registry, you need to add the credentials as servers to **~/.m2/settings.xml** *(for all maven builds)* and also use the new registry as a central mirror 
```
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.1.0"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.1.0 http://maven.apache.org/xsd/settings-1.1.0.xsd">

  <servers>
    <server>
      <id>nexus-snapshots</id>
      <username>admin</username>
      <password>admin123</password>
    </server>
    <server>
      <id>nexus-releases</id>
      <username>admin</username>
      <password>admin123</password>
    </server>
  </servers>

  <mirrors>
    <mirror>
      <id>central</id>
      <name>central</name>
      <url>http://your-host:8081/repository/maven-group/</url>
      <mirrorOf>*</mirrorOf>
    </mirror>
  </mirrors>

</settings>
```

Use the following in the **pom.xml** *(for each project)* 
```
<project ...>
  ...
  <repositories>
    <repository>
      <id>maven-group</id>
      <url>http://your-host:8081/repository/maven-group/</url>
    </repository>
  </repositories>
</project>

```
now with **mvn install** you can download artifacts from the registry. 

## Upload to a maven registry
Add this to the **pom.xml** to be able to use **maven deploy** to push artifacts to the registry: 
```
<project ...>
  ...
  <distributionManagement>
    <snapshotRepository>
      <id>nexus-snapshots</id>
      <url>http://your-host:8081/repository/maven-snapshots/</url>
    </snapshotRepository>
    <repository>
      <id>nexus-releases</id>
      <url>http://your-host:8081/repository/maven-releases/</url>
    </repository>
  </distributionManagement>
</project>
```

# Tipps
Use a script to stop, rebuild and run the script with new **SSL-Certificate's** *(Filename: nexus3-ssl-renew.sh)*: 
```
#!/bin/bash 
cd /opt/nexus 
# get the container id and stop it
docker stop $(docker container ls | grep nexus3-ssl | awk '{print $1}') 
# remove old certs
rm cert.key.pem 
rm fullchain.pem 
# get new certs
cp /etc/letsencrypt/live/www.kunkel24.de-001/privKey.pem cert.key.pem 
cp /etc/letsencrypt/live/www.kunkel24.de-001/fullchain.pem fullchain.pem 
# build and run the new image
docker build --rm=true --tag=nexus3-ssl .
docker run -d --restart=always -p 8081:8081 -p 8082:8082 -p 8083:8083 -p 8443:8443 -v nexus-data:/nexus-data nexus3-ssl
```
and now use this script as a **cronjob** *(crontab -e)*: 
```
35 2 * * 1 /opt/nexus/nexus3-ssl-renew.sh 
```
