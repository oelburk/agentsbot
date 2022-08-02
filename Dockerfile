FROM dart:2.17.1 AS build

WORKDIR /opt/app

#Prep code
COPY pubspec.* ./
RUN dart pub get
COPY . .

#Run bot
CMD ["dart", "bin/beer_bot.dart"]
