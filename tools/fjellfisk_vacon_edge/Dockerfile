FROM node:22-alpine

WORKDIR /opt/fjellfisk-vacon-edge
COPY package.json ./
COPY src ./src

# The protected host config is root-readable only. The container is otherwise
# read-only and drops Linux capabilities in the deployment compose file.
CMD ["node", "src/main.mjs"]
