FROM zeruel92/dart-armv7:latest

#Install git
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y git

#Get req. Dart SDK
WORKDIR /opt/sdk
RUN wget https://storage.googleapis.com/dart-archive/channels/stable/release/2.17.6/sdk/dartsdk-linux-arm-release.zip

RUN unzip -o dartsdk-linux-arm-release.zip
RUN rm dartsdk-linux-arm-release.zip

#Prep. Dart code
WORKDIR /opt/app
RUN cd .. && ls

ADD pubspec.* /opt/app/
RUN pub get
ADD . /opt/app

#Run bot
CMD ["dart", "bin/beer_bot.dart"]
