# Use Node.js official LTS image
FROM node:18-slim

# Set working directory inside the container
WORKDIR /app

# Copy your code into the container
COPY index.js .

# Install express globally (no package.json needed)
RUN npm install express

# Expose the app port
EXPOSE 3000

# Run the app
CMD ["node", "index.js"]

