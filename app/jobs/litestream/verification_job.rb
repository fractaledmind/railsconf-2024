class Litestream::VerificationJob < ApplicationJob
  queue_as :default

  def perform
    Litestream::Commands.databases.each do |database_hash|
      Litestream.verify!(database_hash["path"])
    end
  end
end
