FROM node:22-bookworm-slim

WORKDIR /app

RUN apt-get update \
    && apt-get install --yes --no-install-recommends openssl \
    && rm -rf /var/lib/apt/lists/*

RUN npm install --global pnpm@11.6.0

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY backend/package.json ./backend/package.json
RUN pnpm install --frozen-lockfile --prod=false

COPY backend ./backend
ENV DATABASE_URL=postgresql://build:build@localhost:5432/build
RUN pnpm --filter @what-did-you-do/backend prisma:generate \
    && pnpm --filter @what-did-you-do/backend build

ENV NODE_ENV=production

EXPOSE 3000

CMD ["node", "backend/dist/main.js"]
