FROM node:lts-iron

WORKDIR /app

COPY app/* /app
RUN npm install

CMD ["npm", "start"]