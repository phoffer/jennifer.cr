require "spec"
# require "spec2"
require "./config"
require "./models.cr"
require "./factories.cr"

Spec.before_each do
  Contact.all.delete
  Address.all.delete
  Passport.all.delete
end

# Spec2.random_order
# Spec2.doc
