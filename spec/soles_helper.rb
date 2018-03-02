require 'spec_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

require_relative '../config/app'