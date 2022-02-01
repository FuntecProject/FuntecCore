FROM debian:11
RUN apt update
RUN apt install nodejs -y 
RUN apt install npm -y
RUN apt install curl -y
RUN apt install nano -y
RUN apt-get install libsecret-1-dev -y
WORKDIR /home/node
COPY . .
RUN npm install

