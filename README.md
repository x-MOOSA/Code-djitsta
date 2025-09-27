# Code-djitsta
#include <iostream>
#include <vector>
#include <limits>
#include <algorithm>

// Number of vertices in the graph
constexpr int V = 9;

/**
 * @brief Finds the vertex with the minimum distance value from the set
 * of vertices not yet included in the shortest path tree (sptSet).
 * @param dist The distance array.
 * @param sptSet The set of processed vertices.
 * @return The index of the vertex with the minimum distance.
 */
int minDistance(const std::vector<int>& dist, const std::vector<bool>& sptSet)
{
    // Initialize min value to the maximum possible integer value
    int min = std::numeric_limits<int>::max();
    int min_index = -1;

    for (int v = 0; v < V; v++) {
        if (!sptSet[v] && dist[v] <= min) {
            min = dist[v];
            min_index = v;
        }
    }

    return min_index;
}

/**
 * @brief Utility function to print the constructed distance array.
 * @param dist The distance array.
 */
void printSolution(const std::vector<int>& dist)
{
    std::cout << "Vertex\t\tDistance from Source\n";
    for (int i = 0; i < V; i++) {
        std::cout << i << "\t\t\t\t" << dist[i] << "\n";
    }
}

/**
 * @brief Implements Dijkstra's single source shortest path algorithm for a graph
 * represented using an adjacency matrix.
 * @param graph The adjacency matrix representation of the graph.
 * @param src The source vertex.
 */
void dijkstra(const int graph[V][V], int src)
{
    // The output vector. dist[i] will hold the shortest distance from src to i.
    std::vector<int> dist(V);

    // sptSet[i] will be true if vertex i is included in shortest path tree
    // or shortest distance from src to i is finalized.
    std::vector<bool> sptSet(V);

    // Initialize all distances as INFINITE and sptSet[] as false
    for (int i = 0; i < V; i++) {
        dist[i] = std::numeric_limits<int>::max();
        sptSet[i] = false;
    }

    // Distance of source vertex from itself is always 0
    dist[src] = 0;

    // Find shortest path for all vertices
    for (int count = 0; count < V - 1; count++) {
        // Pick the minimum distance vertex from the set of vertices not yet processed.
        int u = minDistance(dist, sptSet);

        // Mark the picked vertex as processed
        sptSet[u] = true;

        // Update dist value of the adjacent vertices of the picked vertex.
        for (int v = 0; v < V; v++) {
            // Update dist[v] only if:
            // 1. is not in sptSet,
            // 2. there is an edge from u to v (graph[u][v] > 0 for weighted, or simply graph[u][v] if 1/0),
            // 3. and total weight of path from src to v through u is smaller than current value of dist[v]
            if (!sptSet[v] && graph[u][v] && dist[u] != std::numeric_limits<int>::max() &&
                dist[u] + graph[u][v] < dist[v]) {
                dist[v] = dist[u] + graph[u][v];
            }
        }
    }

    // Print the constructed distance array
    printSolution(dist);
}

// Driver program to test above function
int main()
{
    /* Let us create the example graph discussed above */
    int graph[V][V] = {
        { 0, 4, 0, 0, 0, 0, 0, 8, 0 },
        { 4, 0, 8, 0, 0, 0, 0, 11, 0 },
        { 0, 8, 0, 7, 0, 4, 0, 0, 2 },
        { 0, 0, 7, 0, 9, 14, 0, 0, 0 },
        { 0, 0, 0, 9, 0, 10, 0, 0, 0 },
        { 0, 0, 4, 14, 10, 0, 2, 0, 0 },
        { 0, 0, 0, 0, 0, 2, 0, 1, 6 },
        { 8, 11, 0, 0, 0, 0, 1, 0, 7 },
        { 0, 0, 2, 0, 0, 0, 6, 7, 0 }
    };

    // Find shortest path starting from vertex 0
    dijkstra(graph, 0);

    return 0;
}
