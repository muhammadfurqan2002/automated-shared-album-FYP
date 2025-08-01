FROM node:18

# Install ffmpeg + fonts
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ffmpeg \
      fontconfig \
      fonts-dejavu-core \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install
COPY . .

EXPOSE 3000
CMD ["npm", "start"]
