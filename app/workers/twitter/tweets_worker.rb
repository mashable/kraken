class Twitter::TweetsWorker < BaseWorker
  produce every: 1.hour do
    Kraken.config("twitter.yml").tweet_accounts.each do |account|
      perform_async account
    end
  end

  register_connector :s3_json, "twitter.tweets"
  register_connector :s3_avro, "twitter.tweets"

  schema "com.mashable.kraken.twitter.tweet" do
    required :id, :string
    required :user_id, :string
    required :screen_name, :string
    required :favorite_count, :int
    required :is_quote_status, :boolean
    required :retweet_count, :int
    required :is_retweeted, :boolean
    required :text, :string
    required :published_at, :timestamp
  end

  def perform(screen_name)
    tweets = Kraken.config.twitter.user_timeline(screen_name, count: 95)
    key = "#{screen_name}-tweets"
    tweets.each do |tweet|
      next unless add_member key, tweet.id
      payload = {
        id: tweet.id.to_s,
        user_id: tweet.user.id.to_s,
        screen_name: tweet.user.screen_name,
        favorite_count: tweet.favorite_count,
        is_quote_status: tweet.quoted_status?,
        retweet_count: tweet.retweet_count,
        is_retweeted: !!tweet.retweeted?,
        text: tweet.text,
        published_at: tweet.created_at,
      }

      emit 'twitter.tweets', payload, schema: 'com.mashable.kraken.twitter.tweet'
    end
  end
end