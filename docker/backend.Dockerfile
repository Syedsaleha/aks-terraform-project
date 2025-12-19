FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies (lockfile may not exist)
RUN npm install --omit=dev

# Copy application code
COPY . .

# Environment
ENV NODE_ENV=production
ENV PORT=3001

EXPOSE 3001

# ✅ Run the actual entry file
CMD ["node", "index.js"]
