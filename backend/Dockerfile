FROM node:22-alpine AS build
ENV NODE_ENV=production
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev --ignore-scripts
COPY . .

FROM node:22-alpine
ENV NODE_ENV=production
WORKDIR /app
RUN apk del --no-cache npm 2>/dev/null; rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx
COPY --from=build /app /app

USER node
EXPOSE 5000
CMD ["node", "server.js"]