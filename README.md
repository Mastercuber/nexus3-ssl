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
- access UI --> http://hostname:8081 or https://hostname:8443 (if you choose http it will redirect to https)
- default credentials --> username: admin  
                          password: admin123

## Add registrys to Nexus 3
Follow the blog posts to Nexus 3 on [this](http://codeheaven.io) website to configure a Maven, NPM and Docker registry.


## Login to registry (internal)
```
docker login -u admin -p admin123 avensio.org:8082  
docker login -u admin -p admin123 avensio.org:8083
```

## Push to registry (internal)
```
docker tag nexus3-ssl avensio.org:8083/nexus3-ssl
docker push avensio.org:8083/nexus3-ssl
```
## Pull the image (internal)
```
docker pull avensio.org:8082/nexus3-ssl
```
