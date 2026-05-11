global
    log     /dev/log local0
    log     /dev/log local1 notice
    chroot  /var/lib/haproxy
    stats   socket /run/haproxy/admin.sock mode 660 level admin
    stats   timeout 30s
    user    haproxy
    group   haproxy
    daemon

defaults
    log     global
    mode    tcp
    option  tcplog
    timeout connect 5s
    timeout client  50s
    timeout server  50s

frontend openshift-api
    bind *:6443
    mode tcp
    option tcp-check
    default_backend openshift-api-backend

backend openshift-api-backend
    mode tcp
    balance roundrobin
    option tcp-check
%{ for ip in master_ips ~}
    server master${for_each} ${ip}:6443 check fall 3 rise 2
%{ endfor ~}

frontend openshift-bootstrap
    bind *:22623
    mode tcp
    option tcp-check
    default_backend openshift-bootstrap-backend

backend openshift-bootstrap-backend
    mode tcp
    balance roundrobin
    option tcp-check
    server bootstrap ${bootstrap_ip}:22623 check fall 3 rise 2
%{ for ip in master_ips ~}
    server master${for_each} ${ip}:22623 check fall 3 rise 2
%{ endfor ~}

frontend openshift-router
    bind *:443
    mode tcp
    option tcp-check
    default_backend openshift-router-backend

backend openshift-router-backend
    mode tcp
    balance roundrobin
    option tcp-check
%{ for ip in worker_ips ~}
    server worker${for_each} ${ip}:443 check fall 3 rise 2
%{ endfor ~}
