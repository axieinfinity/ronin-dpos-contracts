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

const removeIdentifierSuffix = (type: string) => {
  const suffixIdRegex = /\d+_(storage|memory|calldata|ptr)/g; // id_memory id_storage
  const contractRegex = /^(t_super|t_contract)\(([A-Za-z0-9_]+)\)\d+/g; // t_contract(contractName)id
  const enumRegex = /(t_enum)\(([A-Za-z0-9_]+)\)\d+/g; // t_enum(enumName)id
  return type.replace(suffixIdRegex, '_$1').replace(contractRegex, '$1($2)').replace(enumRegex, '$1($2)');
};

const generateStorageLayoutTable = async ({ source, destination }: { source: string; destination: string }) => {
  try {
    if (fs.existsSync(source)) {
      const fileContent = await fs.readFile(source, 'utf-8');
      const tableContent = preprocessFile(fileContent);
      const listItemOfTable = preprocessTable(tableContent);
      const data = [];
      for (let i = 0; i < listItemOfTable.length; i += 9) {
        // remove two collums: idx (index = 5) and artifacts (index =6)
        const row = listItemOfTable.slice(i, i + 8).filter((_, idx) => idx != 5 && idx != 6);

        // remove the suffix identifier of data type: <id>_(storage|memory|calldata)
        const dataType = row[4];
        row[4] = removeIdentifierSuffix(dataType);
        data.push(row);
      }
      const output = table(data);
      await fs.writeFile(destination, output, 'utf8');
      console.log(`Successful generate storage layout table at ${destination}`);
    } else {
      throw Error(`File storage layout at ${source} not exits`);
    }
  } catch (err) {
    console.error(err);
  }
};

const generateStorageLayoutInline = async ({
  source,
  destination,
  override,
}: {
  source: string;
  destination: string;
  override: boolean;
}) => {
  try {
    if (fs.existsSync(source)) {
      if (!fs.existsSync(destination) || override) {
        const logger = fs.createWriteStream(destination, { flags: 'w' });
        const fileContent = await fs.readFile(source, 'utf-8');
        const tableContent = preprocessFile(fileContent);
        const listItemOfTable = preprocessTable(tableContent);
        let headers: string[] = [];
        const data: string[] = [];
        for (let i = 0; i < listItemOfTable.length; i += 9) {
          // remove two collums: idx (index = 5) and artifacts (index =6)
          const row = listItemOfTable.slice(i, i + 8).filter((_, idx) => idx != 5 && idx != 6);

          // remove the suffix identifier of data type: <id>_(storage|memory|calldata)
          const dataType = row[4];
          row[4] = removeIdentifierSuffix(dataType);
          if (i == 0) {
            headers = row;
          } else {
            data.push(
              `${row[0]}:${row[1]} (${headers[2]}: ${row[2]}) (${headers[3]}: ${row[3]}) (${headers[4]}: ${row[4]}) (${headers[5]}: ${row[5]})`
            );
          }
        }
        logger.write(data.join('\n'));
      } else {
        throw Error(
          `Cannot generate storage layout because file ${destination} already exists. Use the "override" flag to overwrite.`
        );
      }
      console.log(`Successful generate storage layout at ${destination}`);
    } else {
      throw Error(`File storage layout at ${source} not exits`);
    }
  } catch (err) {
    console.error(err);
  }
};
const removeTempStorageLayout = async ({ path }: { path: string }) => {
  try {
    if (fs.existsSync(path)) {
      await fs.unlink(path);
      console.log(`Successful delete temporary storage file`);
    } else {
      throw Error(`File storage layout at ${path} not exits`);
    }
  } catch (err) {
    console.error(err);
  }
};
/// @notice Generate storage layout table from `source` file to `destination` file.
task('generate-storage-layout-table')
  .addParam('source', 'The path to storage layout file extracted from hardhat-storage-layout')
  .addOptionalParam('destination', 'The path to store storage layout after generating', 'logs/storage_layout_table.log')
  .setAction(async ({ source, destination }, _) => {
    await generateStorageLayoutTable({ source, destination });
    await removeTempStorageLayout({ path: source });
  });

/// @notice Generate storage layout in both live from `source` file.
task('generate-storage-layout')
  .addParam('source', 'The path to storage layout file extracted from hardhat-storage-layout')
  .addOptionalParam('override', 'Indicates whether override the destination if it already exits', true, boolean)
  .setAction(async ({ source, override }, hre) => {
    try {
      await generateStorageLayoutTable({ source, destination: 'logs/storage_layout_table.log' });
      await generateStorageLayoutInline({ source, override, destination: 'logs/storage_layout.log' });
      await removeTempStorageLayout({ path: source });
    } catch (err) {
      console.error(err);
    }
  });
