$ORIGIN ${cluster_fqdn}.
$TTL 300
@ IN SOA ns1 ${base_domain}. (
      2026051101
      3600
      1800
      604800
      300 )
@ IN NS ns1.${base_domain}.
api IN A ${lb_ip}
api-int IN A ${lb_ip}
*.apps IN A ${lb_ip}
bootstrap IN A ${bootstrap_ip}
%{ for ip in master_ips ~}
master${for_each} IN A ${ip}
%{ endfor ~}
%{ for ip in worker_ips ~}
worker${for_each} IN A ${ip}
%{ endfor ~}
