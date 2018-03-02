require 'soles_helper'

describe Twitter::TweetsWorker, :vcr do
  it "runs" do
    subject.perform "mashable"
    expect(kafka.channel("twitter.tweets").length).to eq 95
  end
end