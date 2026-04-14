# Build stage
FROM node:20-alpine AS builder
WORKDIR /app

# Copy package manifests and install dependencies for backend and frontend
COPY backend/package.json backend/package-lock.json* ./backend/
COPY frontend/package.json frontend/package-lock.json* ./frontend/

RUN cd backend && npm install
RUN cd frontend && npm install

# Copy source code
COPY backend ./backend
COPY frontend ./frontend

# Build frontend and backend
RUN cd frontend && npm run build
RUN cd backend && npm run build-backend

# Runtime stage
FROM node:20-alpine AS runtime
WORKDIR /app

# Copy runtime dependencies for backend
COPY backend/package.json backend/package-lock.json* ./backend/
RUN cd backend && npm install --production

# Copy built artifacts
COPY --from=builder /app/backend/dist ./backend/dist
COPY --from=builder /app/backend/scripts ./backend/scripts
COPY --from=builder /app/frontend/dist ./frontend/dist

# Expose backend port and set working directory
EXPOSE 3000
WORKDIR /app/backend

CMD ["node", "dist/server.js"]
