
# My Diagram
```mermaid
gantt
    dateFormat YYYY-MM-DD
    title Software Development Timeline 

    section Planning
    Requirements Gathering: task1, 2024-02-27, 2024-03-06
    UI/UX Design:          task2, after task1, 5d

    section Development
    Backend Development:    task3, 2024-03-07, 2024-03-23
    Frontend Development:   task4, after task2, 2024-03-20 
    Integration:            task5, after task3, task4, 5d

    section Testing & Deployment 
    Unit Testing:           task6, 2024-03-28, 4d
    System Testing:         task7, after task6, 5d 
    Bug Fixes:              task8, after task7, 3d
    Deployment:             crit, after task8, 24h  

```

This is a testing diagram for Mermaid.