# POSTGRES HA
PostgreSQL High Availability Setup. Here we are going to talk about a high availability setup for PostgreSQL.

### Table of Contents:
1. Etcd - Leader state, consensus (via Raft). This is used for coordination.  
2. Postgres Stateful Set.  
3. Patroni.  
4. HA Proxy.  
5. PGBackRest - Backup with WAL.  
6. TLS Security.  


## ETCD
Before we understand ETCD, we need to understand what RAFT Consensus is. To understand RAFT Consensus watch this video:
    Understand RAFT Without breaking your brain: https://www.youtube.com/watch?v=IujMVjKvWP4

This video gives us a clear understanding of how RAFT manages, Consensus and Leader Election.

**Leader Election**: The process of electing of electing a new leader from a pool of replicas, when the leader goes down.  
    - All nodes start as followers. With a random leader. The leader periodically sends heartbeats to the followers.  
    - Every follower has a random election timeout (eg: 150 - 300 ms). If followers don't recieve the heartbeat within their own timeouts, they assume the leader is down, and becomes a candidate for the new leader.  
    - Since, the election timeout is random, some followers assume the leader is down, before the others do, they become candidates for the new leader.  
    - 

**Consensus**:


## HAProxy
