FROM ruby:3.3.12

# Install system dependencies and MySQL client
RUN apt-get update -qq && apt-get install -y build-essential default-mysql-client default-libmysqlclient-dev curl git

# Install Node.js and Yarn (in case your frontend requires it)
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && apt-get install -y nodejs
RUN npm install -g yarn

WORKDIR /app

# Install Ruby gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy application code
# Copy application code
COPY . .

# ADD THESE LINES TO FIX WINDOWS FILES:
RUN chmod +x bin/* && \
    sed -i 's/\r$//g' bin/* && \
    sed -i 's/ruby\.exe$/ruby/' bin/*

EXPOSE 3000

# Start the Rails server and bind to all interfaces so your browser can access it
CMD ["bash", "-c", "rm -f tmp/pids/server.pid && bin/rails server -b '0.0.0.0'"]