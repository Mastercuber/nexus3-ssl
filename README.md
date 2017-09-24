# nexus3-ssl

## Login to registry (internal)
docker login -u admin -p admin123 avensio.org:8082  
docker login -u admin -p admin123 avensio.org:8083

## Build the image
docker build --rm=true --tag=avensio/nexus3-ssl .  
its possible to pass args --> --buil-arg SSL_STOREPASS=changeit123 etc..

## Push to registry (internal)
docker tag nexus3-ssl-only avensio.org:8083/nexus3-ssl-only  
docker push avensio.org:8083/nexus3-ssl-only

## Pull the image (internal)
docker pull avensio.org:8082/nexus3-ssl-only

## Run the image
docker run -p 8081:8081 -p 8082:8082 -p 8083:8083 -p 8443:8443 -v nexus-data:/nexus-data sonatype/nexus3
