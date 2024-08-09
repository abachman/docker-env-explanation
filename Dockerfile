FROM node:lts-alpine

WORKDIR /app

COPY app/* /app
RUN npm install

CMD ["npm", "start"]