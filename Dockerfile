# Use official Node.js 18 base image
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy your index.js file
COPY index.js .

# Install express manually without package.json
RUN npm install express

# Expose the port the app runs on
EXPOSE 3000

# Start the application
CMD ["node", "index.js"]
