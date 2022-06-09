FROM node:12-alpine

WORKDIR /app

# Copy package.json & yarn.lock to workdir (/app) & install dependencies.
COPY ./src/web/package.json ./
COPY ./src/web/yarn.lock ./
RUN yarn install --production

COPY ./src/web/ .
CMD ["node", "src/index.js"]
