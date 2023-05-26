import fs from 'fs-extra';
import { table } from 'table';
import { task } from 'hardhat/config';
import { boolean } from 'hardhat/internal/core/params/argumentTypes';

const TABLE_STYLE = {
  /*
      Default Style
      ┌────────────┬─────┬──────┐
      │ foo        │ bar │ baz  │
			├────────────┼─────┼──────┤
      │ frobnicate │ bar │ quuz │
      └────────────┴─────┴──────┘
      */
  headerTop: {
    left: '┌',
    mid: '┬',
    right: '┐',
    other: '─',
  },
  headerBottom: {
    left: '├',
    mid: '┼',
    right: '┤',
    other: '─',
  },
  tableBottom: {
    left: '└',
    mid: '┴',
    right: '┘',
    other: '─',
  },
  vertical: '│',
  rowSeparator: {
    left: '├',
    mid: '┼',
    right: '┤',
    other: '─',
  },
};

const preprocessFile = (fileContent: string) => {
  const whiteSpaceRegex = /[\s,\|]/g; // white space
  // remove all white space
  const fileContentWithoutWhiteSpace = fileContent.replace(whiteSpaceRegex, '');

  // get only table contents
  const startIndex = fileContentWithoutWhiteSpace.indexOf(TABLE_STYLE.headerTop.right);
  const endIndex = fileContentWithoutWhiteSpace.indexOf(TABLE_STYLE.tableBottom.left);
  if (startIndex !== -1 && endIndex !== -1 && startIndex < endIndex) {
    const result = fileContentWithoutWhiteSpace.substring(startIndex + 2, endIndex);
    return result;
  } else {
    throw new Error('File does not contain any table');
  }
};

const preprocessTable = (tableContent: string) => {
  const colorRegex = /\x1B\[\d{1,3}(;\d{1,3})*m/g; // \x1B[30m \x1B[305m \x1B[38;5m
  // remove all color code
  const contentsWithoutColorCode = tableContent.replace(colorRegex, '');
  // get list items by split vertical sperator
  const listItemOfTable = contentsWithoutColorCode.split(TABLE_STYLE.vertical);

  return listItemOfTable;
};

/// @dev Generate storage layout from `source` file to `destination` file.
task('generate-storage-layout')
  .addParam('source', 'The path to storage layout file extracted from hardhat-storage-layout')
  .addOptionalParam('destination', 'The path to store storage layout after generating', 'layout/storage.txt')
  .addOptionalParam('override', 'Indicates whether override the destination if it already exits', false, boolean)
  .setAction(async ({ source, destination, override }, _) => {
    try {
      if (fs.existsSync(source)) {
        const fileContent = await fs.readFile(source, 'utf-8');
        const data = [];
        const tableContent = preprocessFile(fileContent);
        const listItemOfTable = preprocessTable(tableContent);
        for (let i = 0; i < listItemOfTable.length; i += 9) {
          // idx = 5 => idx
          // idx = 6 => artifacts
          const row = listItemOfTable.slice(i, i + 8).filter((_, idx) => idx != 5 && idx != 6);
          data.push(row);
        }
        const output = table(data);
        if (!fs.existsSync(destination) || override) {
          await fs.writeFile(destination, output, 'utf8');
        } else {
          throw Error(
            `Cannot generate storage layout because file ${destination} already exists. Use the "override" flag to overwrite.`
          );
        }
        await fs.unlink(source);
        console.log(`Successful generate storage layout at ${destination}`);
      } else {
        throw Error(`File storage layout at ${source} not exits`);
      }
    } catch (err) {
      console.error(err);
    }
  });
