# docker-centos8-apache24-php74

Dockerfile for Centos8 / Apache2.4 / PHP7.4

## Contents

* Centos 8 base system
* Apache 2.4.37 with OpenSSL 1.1.1c
* PHP 7.4 -  mysqli pdo_mysql pdo_sqlite
* PHP Composer


## Using with docker-compose

```yaml
version: '2'
services:
  phpapp:
    image: 'franciscoigor/php74-apache24-centos8'
    ports:
      - '8000:80'
    volumes:
      - '.:/var/www/html'
```

## Push image to Docker hub

```bash
docker login
docker tag local_image_name username/image-tag-name
docker push username/image-tag-name
```
