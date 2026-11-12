# Étape 1 : installation des dépendances de production uniquement
FROM node:22-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY src ./src

# Étape 2 : image runtime minimale, non-root
FROM node:22-alpine
ENV NODE_ENV=production
# Applique les correctifs de sécurité de l'OS de base (réduit les résultats Trivy)
RUN apk upgrade --no-cache
WORKDIR /app
COPY --from=builder --chown=node:node /app ./

USER node
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/health || exit 1
CMD ["node", "src/index.js"]
