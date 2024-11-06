WORK_DIR=$(dirname $(readlink -f $0))

if [ "$1" = "run" ]; then
    # Build docker containers
    for ((i=0; i<4; i++)); do
        docker run -itd --name=t"${i}" --hostname=t"${i}" --net=none --privileged \
            --sysctl net.ipv4.ip_forward=0 --sysctl net.ipv4.icmp_ratelimit=0 \
            --sysctl net.ipv4.conf.all.rp_filter=0 --sysctl net.ipv4.conf.default.rp_filter=0 \
            --sysctl net.ipv4.conf.lo.rp_filter=0 --sysctl net.ipv4.icmp_echo_ignore_broadcasts=0 \
            --sysctl net.ipv6.conf.all.disable_ipv6=0 --sysctl net.ipv6.conf.default.disable_ipv6=0 \
            --sysctl net.ipv6.conf.all.forwarding=1 --sysctl net.ipv6.conf.all.proxy_ndp=1 \
            --sysctl net.ipv6.conf.default.proxy_ndp=1 \
            -v /etc/localtime:/etc/localtime:ro \
            -v ${WORK_DIR}/t${i}/:/etc/frr/ \
            ponedo/frr-ubuntu20:tiny
        container_pid=$(docker inspect -f '{{.State.Pid}}' t${i})
        ln -s /proc/$container_pid/ns/net /var/run/netns/t${i}
        # docker exec -i t$i ip6tables -A INPUT -d ff02::16 -j DROP
        # docker exec -i t$i ip6tables -A OUTPUT -d ff02::16 -j DROP
        #docker exec -i t$i ip6tables -A OUTPUT -p icmpv6 --icmpv6-type echo-reply -d ff02::16 -j DROP
    done;
    # Setup links
    ip netns exec t0 ip link add eth01 type veth peer name eth11 netns t1
    ip netns exec t0 ip link add eth02 type veth peer name eth21 netns t2
    ip netns exec t1 ip link add eth12 type veth peer name eth31 netns t3
    ip netns exec t0 ip link set eth01 up
    ip netns exec t0 ip link set eth02 up
    ip netns exec t1 ip link set eth11 up
    ip netns exec t1 ip link set eth12 up
    ip netns exec t2 ip link set eth21 up
    ip netns exec t3 ip link set eth31 up
    
    
    ip netns exec t0 ip addr add 2001:0000::1/32 dev eth01
    ip netns exec t0 ip addr add 2001:2000::2/32 dev eth02
    ip netns exec t1 ip addr add 2001:1000::11/32 dev eth11
    ip netns exec t1 ip addr add 2001:3000::12/32 dev eth12
    ip netns exec t2 ip addr add 2001:2000::21/32 dev eth21
    ip netns exec t3 ip addr add 2001:3000::31/32 dev eth31
    ip netns exec t2 ip -6 route add default via 2001:2000::2 dev eth21
    ip netns exec t3 ip -6 route add default via 2001:3000::12 dev eth31

    # Run FRRs
    for ((i=0; i<4; i++)); do
        docker exec -i t"${i}" /usr/lib/frr/frrinit.sh start
    done;

elif [ "$1" = "rm" ]; then
    # Delete docker containers
    for ((i=0; i<4; i++)); do
        docker rm -f t${i};
        rm -f /var/run/netns/t${i}
    done
else
    echo "Usage:"
    echo -e "\t$0 COMMAND"
    echo -e "\tCOMMAND could be: \"run\" or \"rm\""
fi