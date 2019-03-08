source /home/vagrant/perl5/perlbrew/etc/bashrc
export HTTPS_PROXY=http://wwwcache.sanger.ac.uk:3128
export http_proxy=http://wwwcache.sanger.ac.uk:3128
export https_proxy=http://wwwcache.sanger.ac.uk:3128
export HTTP_PROXY=http://wwwcache.sanger.ac.uk:3128
[[ ":$PATH:" != *":/vagrant/PathFind/bin:"* ]] && PATH="/vagrant/PathFind/bin:${PATH}"
[[ ":$PATH:" != *":/vagrant/vr-codebase/bin:"* ]] && PATH="/vagrant/vr-codebase/bin:${PATH}"
export PATH
[[ ":$PERL5LIB:" != *":/vagrant/PathFind/lib:"* ]] && PERL5LIB="/vagrant/PathFind/lib:${PERL5LIB}"
[[ ":$PERL5LIB:" != *":/vagrant/vr-codebase/modules:"* ]] && PERL5LIB="/vagrant/vr-codebase/modules:${PERL5LIB}"
export PERL5LIB
perlbrew switch perl-5.14.2
