FROM node:20-slim

# Set working directory
WORKDIR /app

# Copy package files (local to context)
COPY package*.json ./

# Install dependencies
RUN npm install --production

# Copy source code (local to context)
COPY index.js ./

# Set environment variables
ENV PORT=8080

# Expose port
EXPOSE 8080

# Run the application
CMD ["node", "index.js"]
