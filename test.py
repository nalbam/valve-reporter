import csv

def main():
    with open('cost.txt', 'r') as in_file:
        stripped = (line.strip() for line in in_file)
        lines = (line.split() for line in stripped if "#" not in line )
        with open('log.csv', 'w') as out_file:
            writer = csv.writer(out_file)
            writer.writerow(('Start time', 'End time', 'Cost'))
            writer.writerows(lines)

if __name__ == '__main__':
    main()
