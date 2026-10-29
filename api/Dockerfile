# Imagen base liviana (Alpine) para que el contenedor pese poco y arranque rápido
FROM node:20-alpine

WORKDIR /app

# Primero solo las dependencias, para aprovechar la caché de capas de Docker
COPY package*.json ./
RUN npm install --omit=dev && npm cache clean --force

COPY server.js ./

ENV NODE_ENV=production PORT=3000
EXPOSE 3000

# No correr como root
USER node

CMD ["node", "server.js"]
