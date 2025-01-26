FROM dart:stable AS build

WORKDIR /opt/app

#Prep code
COPY pubspec.* ./
RUN dart pub get
COPY . .

#Run bot
CMD ["dart", "bin/beer_bot.dart"]
