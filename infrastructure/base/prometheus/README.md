# Prometheus for Rucio

We run our own prometheus server in our kubernetes cluster. 
CERN provides one, which must be declined in the cluster creation as documented in the top level instructions for flux.
We must run our own because of some of the configuration we do. 

Our prometheus infrastructure has several behaviors that are not quite standard. 
Rather than allowing an external service to scrape our prometheus servers (and open up another named endpoint), we push our metrics to the CMS high availability servers.
To allow our probes, which are short lived, to generate metrics we run a prometheus push gateway which accepts metrics from the probes and holds them until the Rucio prometheus can scrape them.

Finally we also (currently) scrape metrics from a statsd to prometheus translation layer. 
Statsd is the metric service originally used by Rucio. 
It is not as nice as prometheus as it had no labels; we have some additional configs to turn long statsd metric names into shorter prometheus names with apporpriate labels.
All statsd metrics from the rucio servers and daemons should be reproduced nicely in prometheus; statsd is still the only way we can get some of our probes.
