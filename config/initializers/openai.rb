OpenAI.configure do |config|
    config.access_token = ENV['OPENAI_API_KEY']
    config.log_errors = true # Highly recommended in development, so you can see what errors OpenAI is returning. Not recommended in production because it could leak private data to your logs.
  end
  