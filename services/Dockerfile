FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY src ./src
COPY scripts ./scripts
USER node
# ROLE define qual serviço sobe: bff | payment | acquirer
CMD ["node", "src/index.js"]
