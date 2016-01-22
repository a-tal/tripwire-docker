# Tripwire-docker

This builds a container for Tripwire (https://bitbucket.org/daimian/tripwire),
the EVE Online wormhole mapper web app.

To build:

```docker build -t tripwire .```

To run:

```
docker run -d --name=tripwire \
-e DB_USERNAME=tripwire \
-e DB_PASSWORD=somesqlpassword \
-e ADMIN_EMAIL=tripwire@your.host \
-e SERVER_NAME=your.host \
-e SSO_CLIENT_ID=your_client_id \
-e SSO_SECRET_KEY=your_secret_key \
-p 8080:80 \
tripwire
```

Get your SSO client and secret key from https://developers.eveonline.com/applications/
