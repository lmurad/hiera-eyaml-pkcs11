require 'hiera/backend/eyaml/encryptor'
require 'hiera/backend/eyaml/utils'
require 'hiera/backend/eyaml/options'
require "rubygems"
require "pkcs11"

class Hiera
  module Backend
    module Eyaml
      module Encryptors
        class Pkcs11 < Encryptor
          include PKCS11
          self.options = {


            :offline => { :desc => "Work in offline mode using offline publickey",
                          :type => :boolean,
                          :default => false },


            :offline_publickey => { :desc => "Local path to the Public key used in offline mode",
                                    :type => :string,
                                    :default => "/etc/puppetlabs/puppet/ssl/keys/pkcs11.publickey.pem" },


            :hsm_library => { :desc => "HSM Shared object library path",
                              :type => :string,
                              :default => "/opt/nfast/toolkits/pkcs11/libcknfast.so" },


            :hsm_usertype => { :desc => "HSM Softcard user type CKU_<foo>",
                               :type => :string,
                               :default => "#{:USER}" },

            :hsm_password => { :desc => "HSM Softcard Password",
                               :type => :string,
                               :default => "badpassword" },
          }

          self.tag = "PKCS11"

          def self.encrypt plaintext
             self.session(:encrypt,plaintext)
          end

          def self.decrypt ciphertext
             self.session(:decrypt,ciphertext)
          end

          def self.session(action,text)

            hsm_usertype  = self.option :hsm_usertype
            hsm_password  = self.option :hsm_password
            hsm_library   = self.option :hsm_library
            raise StandardError, "hsm_usertype is not defined"  unless hsm_usertype
            raise StandardError, "hsm_password is not defined"  unless hsm_password
            raise StandardError, "hsm_library is not defined"   unless hsm_library

            pkcs11 = PKCS11.open(hsm_library)
            p pkcs11.info  # => #<PKCS11::CK_INFO cryptokiVersion=...>
            puts "SLOTS: #{pkcs11.active_slots}"
            pkcs11.active_slots[3].open do |session|
              session.login(hsm_usertype,hsm_password)
              
              public_key  = session.find_objects(:CLASS => PKCS11::CKO_PUBLIC_KEY).first
              private_key = session.find_objects(:CLASS => PKCS11::CKO_PRIVATE_KEY).first
              puts "Found private key: #{private_key[:LABEL]}"
              puts "Found public key:  #{public_key[:LABEL]}"
             
              if action == :encrypt
                puts "Session: #{session.info.inspect}"
                result = session.encrypt(:RSA_PKCS,public_key,text)
              elsif action == :decrypt
                # Decode Base64 text and decrypt original plaintext and return
                result = session.decrypt( :RSA_PKCS,private_key,text)
              end
              session.logout
              result
            end
          end

          def self.create_keys
              #    pub_key, priv_key = session.generate_key_pair(:RSA_PKCS_KEY_PAIR_GEN,
              #          {:MODULUS_BITS=>2048, :PUBLIC_EXPONENT=>[3].pack("N"), :TOKEN=>false},
              #                {})
             raise StandardError "Not implemented"
          end
         end
      end
    end
  end
end
