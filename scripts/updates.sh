bosh upload-release --sha1 66b8a0d51b0436bd615eb9b99fc5d3963dd87efa \
  https://bosh.io/d/github.com/concourse/concourse-bosh-release?v=5.8.0

bosh upload-release --sha1 1c678e1c7a3506c0e408860571560081c15e3c6d \
  https://bosh.io/d/github.com/cloudfoundry/garden-runc-release?v=1.19.9

bosh upload-release --sha1 225d508eed11c3f6f4a360118de068d5db9fa427 \
  https://bosh.io/d/github.com/pivotal-cf/credhub-release?v=2.5.9

bosh upload-release --sha1 5fdd99addec2aebe521a468dba0bcd52e66c86c6 \
  https://bosh.io/d/github.com/cloudfoundry/uaa-release?v=74.12.0

bosh upload-release --sha1 5bad6161dbbcf068830a100b6a76056fe3b99bc8 \
  https://bosh.io/d/github.com/cloudfoundry/bpm-release?v=1.1.6

bosh upload-stemcell --sha1 6049ba1da8606c42494044f64ea4f831a942fa9b \
  https://bosh.io/d/stemcells/bosh-azure-hyperv-ubuntu-xenial-go_agent?v=621.41 
