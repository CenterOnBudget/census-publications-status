# Census Publications Status

See which Census Bureau publications have been removed from the web.

Currently covers:

-   [Working papers](https://www.census.gov/library/working-papers.html), [America Counts stories](https://www.census.gov/AmericaCounts), [publications](https://www.census.gov/library/publications.html) (reports, briefs, etc.)
-   Published 2018 to 2025 YTD[^readme-1]

[^readme-1]: Based on URL structure; for example "census.gov/library/working-papers/2025/". Actual publish date may differ.

### Overview

1.  Via the [Wayback CDX server](https://github.com/internetarchive/wayback/tree/master/wayback-cdx-server#readme), compile lists (in `data/urls/`) of all webpages with the following prefixes that were ever snapshotted by the [Internet Archive](https://archive.org/):
    -   census.gov/library/working-papers/{year}/
    -   census.gov/library/stories/{year}/
    -   census.gov/library/publications/{year}/
2.  Find the current HTML status code of each webpage (in `data/status`).
3.  Make a list of removed webpages (`data/removed_cen_pubs.csv`).

For each removed webpage, I manually navigated to the Wayback snapshot to find the publication title. I also performed Google searches for select publications to see if they had been moved elsewhere on the Census website. I manually inserted this info into `data/removed_cen_pubs.xlsx`.

### Limitations

-   False positives and negatives
    -   Includes webpages that were removed or relocated for benign reasons and/or prior to January 2025
    -   Omits webpages that were never snapshotted by the Internet Archive
-   Presumably, as new webpages go up and more webpages are taken down, it will be desirable to regenerate the URL lists and re-check statuses, but the code is not optimized for this
-   Finding publication titles is not automated